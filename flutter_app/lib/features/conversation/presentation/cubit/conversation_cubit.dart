import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/services/alarm_service.dart';
import '../../../../core/services/dialect_detector.dart';
import '../../../../core/utils/navigation_service.dart';
import '../../../islamic/domain/entities/islamic_advice.dart';
import '../../../islamic/domain/entities/surah.dart';
import '../../data/datasources/conversation_remote_datasource.dart';
import '../../data/datasources/rafeeq_ai_api_client.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/detected_intent.dart';
import '../../domain/services/intent_detector.dart';
import '../../domain/services/voice_flow_manager.dart';
import '../../../emergency/data/models/emergency_contact_model.dart';
import '../../../reminders/domain/entities/reminder.dart';
import '../../../islamic/domain/usecases/calculate_prayer_times.dart';
import '../../../islamic/domain/usecases/get_advice_list.dart';
import '../../../islamic/domain/usecases/get_daily_advice.dart';
import '../../../islamic/domain/usecases/get_surahs.dart';
import '../../../diet/domain/usecases/get_diet_plan.dart';
import '../../../diet/domain/entities/bmi_result.dart';
import '../../../diet/domain/entities/meal.dart';
import '../../../locations/domain/usecases/get_places_by_category.dart';
import '../../../locations/domain/usecases/get_current_location.dart';
import '../../../locations/domain/entities/place.dart';
import 'package:url_launcher/url_launcher.dart';
import 'conversation_state.dart';

class ConversationCubit extends Cubit<ConversationState> {
  final IntentDetector _intentDetector;
  final RafeeqAiApiClient _rafeeqApi;
  final TtsService _tts;
  final stt.SpeechToText _speech;
  final VoiceFlowManager _flowManager;
  final ConversationRemoteDataSource _remoteDs;

  // ── Use cases for direct action execution ─────────────────────────────────
  final CalculatePrayerTimes _calculatePrayerTimes;
  final GetDailyAdvice _getDailyAdvice;
  final GetSurahs _getSurahs;
  final GetDietPlan _getDietPlan;
  final GetPlacesByCategory _getPlaces;
  final GetCurrentLocation _getCurrentLocation;

  // Dialect auto-detection — pure, no I/O.
  final _dialectDetector = const DialectDetector();

  /// Concatenated user utterances for the current session. More text = more
  /// reliable dialect detection, so we accumulate rather than score per turn.
  String _accumulatedUserText = '';

  /// When false the TTS completion handler will not auto-restart listening.
  bool _autoListen = true;

  /// When true, the next voice input is routed directly to Gemini.
  bool _geminiMode = false;

  /// Active Firestore session id (null until startSession resolves).
  String? _sessionId;

  ConversationCubit({
    required IntentDetector intentDetector,
    required RafeeqAiApiClient rafeeqApi,
    required TtsService tts,
    required stt.SpeechToText speech,
    required VoiceFlowManager flowManager,
    required ConversationRemoteDataSource remoteDs,
    required CalculatePrayerTimes calculatePrayerTimes,
    required GetDailyAdvice getDailyAdvice,
    required GetSurahs getSurahs,
    required GetDietPlan getDietPlan,
    required GetPlacesByCategory getPlaces,
    required GetCurrentLocation getCurrentLocation,
  })  : _intentDetector = intentDetector,
        _rafeeqApi = rafeeqApi,
        _tts = tts,
        _speech = speech,
        _flowManager = flowManager,
        _remoteDs = remoteDs,
        _calculatePrayerTimes = calculatePrayerTimes,
        _getDailyAdvice = getDailyAdvice,
        _getSurahs = getSurahs,
        _getDietPlan = getDietPlan,
        _getPlaces = getPlaces,
        _getCurrentLocation = getCurrentLocation,
        super(const ConversationState());

  // ─── Session logging helpers ──────────────────────────────────────────────

  Future<void> _startSession() async {
    try {
      final doc = await _remoteDs.startSession();
      _sessionId = doc['id'] as String?;
    } catch (_) {
      // Logging is non-critical — conversation still works offline
    }
  }

  /// Log a user→bot exchange to Firestore best-effort.
  void _logExchange(String userText, String botText) {
    final sid = _sessionId;
    if (sid == null) return;
    _remoteDs
        .sendMessage(sid, userText)
        .catchError((_) => <String, dynamic>{});
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // Start Firestore session for history logging (best-effort)
    _startSession();

    _tts.setCompletionHandler(() {
      if (!isClosed) {
        emit(state.copyWith(
          isSpeaking: false,
          status: ConversationStatus.idle,
        ));
        if (_autoListen) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!isClosed && !state.isListening) {
              startListening();
            }
          });
        }
        _autoListen = true;
      }
    });

    // Request mic permission before initializing speech engine
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await Permission.microphone.request();
    }

    final available = await _speech.initialize(
      onError: (error) {
        if (!isClosed && error.errorMsg != 'error_speech_timeout') {
          emit(state.copyWith(
            isListening: false,
            partialText: '',
            status: ConversationStatus.idle,
          ));
        }
      },
    );

    if (!available) {
      if (!isClosed) {
        emit(state.copyWith(
          status: ConversationStatus.error,
          errorMessage: 'خدمة التعرف على الصوت غير متاحة. تأكد أن الجهاز يدعم التعرف على الصوت.',
        ));
      }
      return;
    }

    // Auto-start listening once speech engine is ready
    await startListening();
  }

  // ─── Listening control ───────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (state.isListening || state.isSpeaking) return;

    // Haptic tap feedback — fire immediately before any async work
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(StorageKeys.hapticFeedbackEnabled) ?? true) {
      HapticFeedback.mediumImpact();
    }

    // If speech engine not available (no Google Speech service on device/emulator)
    if (!_speech.isAvailable) {
      emit(state.copyWith(
        status: ConversationStatus.error,
        errorMessage: 'خدمة التعرف على الصوت غير متاحة على هذا الجهاز',
      ));
      return;
    }

    emit(state.copyWith(
      isListening: true,
      partialText: '',
      status: ConversationStatus.listening,
    ));

    await _speech.listen(
      localeId: 'ar-SA',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        if (isClosed) return;
        if (!result.finalResult) {
          emit(state.copyWith(partialText: result.recognizedWords));
        } else if (result.recognizedWords.isNotEmpty) {
          _processSpeech(result.recognizedWords);
        } else {
          emit(state.copyWith(
            isListening: false,
            partialText: '',
            status: ConversationStatus.idle,
          ));
        }
      },
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    if (!isClosed) {
      emit(state.copyWith(
        isListening: false,
        partialText: '',
        status: ConversationStatus.idle,
      ));
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (!isClosed) {
      emit(state.copyWith(
        isSpeaking: false,
        status: ConversationStatus.idle,
      ));
    }
  }

  // ─── Core processing ─────────────────────────────────────────────────────────

  Future<void> _processSpeech(String text) async {
    await stopListening();

    final userMsg = ConversationMessage(
      id: const Uuid().v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    emit(state.copyWith(
      messages: [...state.messages, userMsg],
      status: ConversationStatus.processing,
      partialText: '',
    ));

    // Accumulate text and run dialect detection before any downstream call
    // so the updated dialect is already in SharedPreferences when
    // _buildSystemInstruction() reads it for this same turn.
    _accumulatedUserText += ' $text';
    // Cap accumulator so old signal doesn't dominate forever — when the user
    // switches dialect mid-session the new utterances must be able to win.
    if (_accumulatedUserText.length > 600) {
      _accumulatedUserText =
          _accumulatedUserText.substring(_accumulatedUserText.length - 600);
    }
    _detectAndSaveDialect(text);

    final normalized = _normalizeForExtraction(text);

    // ── Gemini mode: all speech goes to Gemini until chat is reset ──────────
    if (_geminiMode) {
      await askGemini(text);
      return;
    }

    // ── Check if user wants to cancel the current flow ───────────────────────
    if (state.hasActiveFlow && _isCancelCommand(normalized)) {
      await _respondAndListen('تمام، الغيت الطلب. كيف اقدر اساعدك؟',
          clearFlow: true);
      return;
    }

    // ── Gemini voice keyword: "جيميني ..." ──────────────────────────────────
    if (_isGeminiKeyword(normalized)) {
      final question = _extractGeminiQuestion(text, normalized);
      if (question.isNotEmpty) {
        await askGemini(question);
      } else {
        await activateGeminiVoice();
      }
      return;
    }

    // ── Reset chat keyword ───────────────────────────────────────────────────
    if (_isResetKeyword(normalized)) {
      await resetChat();
      return;
    }

    // ── If there's an active flow, treat this as a slot answer ───────────────
    if (state.hasActiveFlow) {
      await _processSlotAnswer(text);
      return;
    }

    // ── Social/courtesy phrases get canned, dialect-appropriate replies ─────
    // before we hit the intent system. This runs identically whether the
    // remote AI API is reachable or not — the user gets a respectful
    // response either way. Phrases that map to a real action (emergency,
    // locations, reminders, …) intentionally fall through to intent
    // detection below where the keyword list already covers them.
    final socialReply = _handleSocialPhrase(normalized);
    if (socialReply != null) {
      await _respondAndListen(socialReply, clearFlow: true);
      return;
    }

    // ── No active flow — detect intent ──────────────────────────────────────
    // Always run the local detector first: it supplies extractedParams
    // (reminder time, surah name, location category, …) that the API does
    // not return, and it acts as the fallback when the API is unreachable.
    final localIntent = _intentDetector.detect(text);
    final intent = await _classifyWithApiOrLocal(text, localIntent);
    emit(state.copyWith(detectedIntent: intent));

    // Emergency — call first saved emergency contact directly
    if (intent.isEmergency) {
      _autoListen = false;
      await _executeEmergencyCall();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 250));

    // Check if this intent has a multi-turn flow
    if (_flowManager.needsSlots(intent.type)) {
      await _startFlow(intent);
    } else {
      // No slots needed — execute immediately
      await _executeDirectAction(intent.type, intent.extractedParams);
    }
  }

  // ─── Rafeeq AI API integration ────────────────────────────────────────────

  /// Try the remote Rafeeq AI API for intent classification. On any failure
  /// (server down, timeout, unknown label) returns [localIntent] unchanged
  /// so the user gets the existing keyword-based behaviour.
  ///
  /// When the API succeeds we override the intent *type* with the server's
  /// answer but keep [localIntent.extractedParams], because the server only
  /// returns a label — parameter extraction (reminder time, surah name,
  /// location category, …) is still client-side.
  Future<DetectedIntent> _classifyWithApiOrLocal(
    String text,
    DetectedIntent localIntent,
  ) async {
    try {
      if (!await _rafeeqApi.isHealthy()) return localIntent;

      final prediction = await _rafeeqApi.predictText(text);

      // Apply API-detected dialect immediately — the API sees the full
      // text and has a more reliable signal than the local accumulator
      // (which needs several utterances to gain confidence).
      if (prediction.dialect != null) {
        _applyApiDialect(prediction.dialect!);
      }

      final apiType = _mapApiIntent(prediction.intent);
      if (apiType == null) return localIntent;

      // If the server says "general" but the local detector matched
      // something more specific, trust the local one.
      if (apiType == IntentType.general &&
          localIntent.type != IntentType.general) {
        return localIntent;
      }

      return DetectedIntent(
        type: apiType,
        confidence: 1.0,
        matchedText: prediction.text.isNotEmpty ? prediction.text : text,
        extractedParams: localIntent.extractedParams,
      );
    } catch (_) {
      _rafeeqApi.invalidateHealthCache();
      return localIntent;
    }
  }

  /// Map the snake_case intent string returned by rafeeq_ai_api to the
  /// Flutter [IntentType] enum. Returns null if the label is unknown.
  static IntentType? _mapApiIntent(String apiIntent) {
    switch (apiIntent) {
      case 'emergency':      return IntentType.emergency;
      case 'prayer_time':    return IntentType.prayerTime;
      case 'medication':     return IntentType.medication;
      case 'diet':           return IntentType.diet;
      case 'reminders':      return IntentType.reminders;
      case 'quran':          return IntentType.quran;
      case 'islamic_advice': return IntentType.islamicAdvice;
      case 'locations':      return IntentType.locations;
      case 'conversation':   return IntentType.conversation;
      case 'general':        return IntentType.general;
    }
    return null;
  }

  // ─── Multi-turn flow management ────────────────────────────────────────────

  Future<void> _startFlow(DetectedIntent intent) async {
    final flow = _flowManager.getFlow(intent.type);
    if (flow == null) return;

    // Pre-fill any slots already extracted from the initial command
    final prefilledSlots = Map<String, String>.from(intent.extractedParams);

    emit(state.copyWith(
      activeFlowIntent: intent.type,
      collectedSlots: prefilledSlots,
    ));

    // Check if some/all slots are already filled
    final nextSlot = _flowManager.getNextSlot(intent.type, prefilledSlots);
    if (nextSlot == null) {
      // All slots already filled from the initial command
      await _executeDirectAction(intent.type, prefilledSlots);
      return;
    }

    // Speak intro + first question
    final intro = flow.introPrompt.isNotEmpty
        ? '${flow.introPrompt} ${nextSlot.promptArabic}'
        : nextSlot.promptArabic;

    emit(state.copyWith(currentSlotKey: nextSlot.key));
    await _respondAndListen(intro);
  }

  Future<void> _processSlotAnswer(String rawText) async {
    final intentType = state.activeFlowIntent!;
    final currentKey = state.currentSlotKey;

    if (currentKey == null) {
      // Shouldn't happen, but recover
      await _respondAndListen('عذرا، ممكن تعيد؟');
      return;
    }

    // Find the current slot definition
    final flow = _flowManager.getFlow(intentType);
    if (flow == null) return;

    SlotDefinition? currentSlotDef;
    for (final s in flow.slots) {
      if (s.key == currentKey) {
        currentSlotDef = s;
        break;
      }
    }
    if (currentSlotDef == null) return;

    // Normalize for extraction
    final normalizedText = _normalizeForExtraction(rawText);

    // Try to extract the slot value
    final value = _flowManager.extractSlotValue(
      currentSlotDef.type,
      normalizedText,
      rawText,
    );

    if (value == null) {
      // Couldn't understand — re-ask
      await _respondAndListen(
        'ما فهمت عليك. ${currentSlotDef.promptArabic}',
      );
      return;
    }

    // Store the slot value
    final updatedSlots = Map<String, String>.from(state.collectedSlots);
    updatedSlots[currentKey] = value;
    emit(state.copyWith(collectedSlots: updatedSlots));

    // Check if there's a next slot
    final nextSlot = _flowManager.getNextSlot(intentType, updatedSlots);
    if (nextSlot != null) {
      // Ask for the next slot
      emit(state.copyWith(currentSlotKey: nextSlot.key));
      await _respondAndListen('تمام. ${nextSlot.promptArabic}');
    } else {
      // All slots collected — execute the action
      await _executeDirectAction(intentType, updatedSlots);
    }
  }

  // ─── Direct action execution ──────────────────────────────────────────────

  Future<void> _executeDirectAction(
    IntentType type,
    Map<String, String> params,
  ) async {
    String response;

    switch (type) {
      case IntentType.reminders:
      case IntentType.medication:
        response = await _executeReminder(type, params);
        break;
      case IntentType.prayerTime:
        response = await _executePrayerTimes(params);
        break;
      case IntentType.diet:
        response = await _executeDiet(params);
        break;
      case IntentType.locations:
        response = await _executeLocations(params);
        break;
      case IntentType.quran:
        response = await _executeQuran(params);
        break;
      case IntentType.islamicAdvice:
        response = await _executeIslamicAdvice();
        break;
      case IntentType.conversation:
        response = 'أنا هنا معك. تفضل بالحديث، وأنا أستمع.';
        break;
      case IntentType.general:
        response = 'سمعتك. كيف أقدر أساعدك؟ '
            'قل مثلاً: ذكرني، صلاة، قرآن، أكل، وين، أو نجدة.';
        break;
      case IntentType.emergency:
        response = 'جاري الاتصال للمساعدة الآن!';
        break;
      case IntentType.deviceControl:
        response = await _executeDeviceControl(params);
        break;
    }

    // Append a follow-up prompt so the assistant stays conversational and
    // doesn't go silent after completing a single request. Skip for intents
    // that either navigate away (quran with a specific surah, emergency) or
    // are already follow-ups themselves (conversation, general).
    final shouldFollowUp = !_isNavigatingAway(type, params) &&
        type != IntentType.emergency &&
        type != IntentType.conversation &&
        type != IntentType.general;
    if (shouldFollowUp && !_endsWithFollowUp(response)) {
      response = '$response تحتاج شي ثاني؟';
    }

    // Log the exchange to Firestore (best-effort) and speak the result
    final userText = state.messages.isNotEmpty && state.messages.last.isUser
        ? state.messages.last.text
        : '';
    _logExchange(userText, response);
    await _respondAndListen(response, clearFlow: true);
  }

  /// Returns true when the intent causes a page navigation so we skip the
  /// "تحتاج شي ثاني؟" follow-up prompt.
  bool _isNavigatingAway(IntentType type, Map<String, String> params) {
    if (type == IntentType.quran && (params['surah'] ?? '').isNotEmpty) {
      return true;
    }
    if (type == IntentType.locations) return true;
    return false;
  }

  /// Folds Arabic letter variants so surah matching tolerates common STT
  /// spellings (ة↔ه, ى↔ي, أ/إ/آ→ا, stray diacritics and tatweel).
  static String _looseFoldArabic(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[ً-ٰٟؐ-ؚ]'), '');
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// True when the response already invites further conversation, so we don't
  /// tack on a duplicate "تحتاج شي ثاني؟".
  static bool _endsWithFollowUp(String text) {
    final t = text.trim();
    return t.endsWith('تحتاج شي ثاني؟') ||
        t.endsWith('تحتاج شيء ثاني؟') ||
        t.endsWith('فيه شي ثاني؟') ||
        t.endsWith('كيف أقدر أساعدك؟') ||
        t.endsWith('كيف اقدر اساعدك؟');
  }

  // ── Emergency call ────────────────────────────────────────────────────────

  Future<void> _executeEmergencyCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(StorageKeys.emergencyContacts);

      if (jsonString == null || jsonString.isEmpty) {
        await _tts.speak(
            'لا يوجد أرقام طوارئ محفوظة. يرجى إضافة رقم من صفحة الطوارئ.');
        return;
      }

      final contacts = EmergencyContactModel.listFromJsonString(jsonString);
      if (contacts.isEmpty) {
        await _tts.speak('لا يوجد أرقام طوارئ محفوظة.');
        return;
      }

      final first = contacts.first;
      final phone = first.phone.trim();

      // Announce the call, then wait for TTS to finish before opening dialler
      await _tts.speak('جاري الاتصال بـ ${first.name}.');
      await Future.delayed(const Duration(milliseconds: 1800));

      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await _tts.speak('لم أتمكن من فتح تطبيق الاتصال.');
      }
    } catch (_) {
      await _tts.speak('حدث خطأ أثناء محاولة الاتصال.');
    }
  }

  Future<String> _executeReminder(
    IntentType type,
    Map<String, String> params,
  ) async {
    final title = params['title'] ?? 'تذكير';
    final timeStr = params['time'] ?? '';
    final now = DateTime.now();
    DateTime scheduledTime;

    if (timeStr.startsWith('+')) {
      // Relative time
      final parts = timeStr.substring(1);
      if (parts.endsWith('h')) {
        final hours = int.tryParse(parts.replaceAll('h', '')) ?? 1;
        scheduledTime = now.add(Duration(hours: hours));
      } else {
        final minutes = int.tryParse(parts.replaceAll('m', '')) ?? 10;
        scheduledTime = now.add(Duration(minutes: minutes));
      }
    } else if (timeStr.contains(':')) {
      final timeParts = timeStr.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    } else {
      scheduledTime = now.add(const Duration(hours: 1));
    }

    final reminderType = type == IntentType.medication
        ? ReminderType.medication
        : _inferReminderType(title);

    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      scheduledTime: scheduledTime,
      type: reminderType,
      repeat: RepeatInterval.none,
    );

    final alarmResult =
        await GetIt.instance<AlarmService>().addAndSchedule(reminder);
    final timeDisplay = _formatTimeArabic(scheduledTime);

    if (alarmResult.disabledInApp) {
      return 'تم حفظ التذكير لكن التنبيهات مقفلة من الإعدادات. '
          'افتح الإعدادات وفعّل التذكيرات لتسمع التنبيه.';
    }
    if (alarmResult.timeInPast) {
      return 'الوقت اللي قلته عدى. قل وقت ثاني بعد الآن.';
    }
    if (alarmResult.isScheduledExact) {
      return 'تم ضبط تذكير "$title" $timeDisplay. إن شاء الله اذكرك.';
    }
    if (alarmResult.needsPermission) {
      return 'تم ضبط تذكير "$title" $timeDisplay. '
          'ملاحظة: قد يتأخر التنبيه دقائق. لضبط دقيق، فعّل '
          '"السماح بالمنبهات الدقيقة" لتطبيق رفيق من إعدادات الهاتف.';
    }
    return 'تم حفظ التذكير "$title" $timeDisplay، '
        'بس صار خطأ بضبط التنبيه. تحقق من إذن الإشعارات.';
  }

  Future<String> _executePrayerTimes(Map<String, String> params) async {
    // Use default Riyadh coordinates; a real implementation would use GPS
    final result = await _calculatePrayerTimes(lat: 24.7136, lng: 46.6753);
    return result.fold(
      (failure) => 'عذرا، ما قدرت أجيب أوقات الصلاة.',
      (prayerTimes) {
        final fmt = DateFormat('h:mm', 'ar');
        final buffer = StringBuffer('ابشر! أوقات الصلاة اليوم: ');
        buffer.write('الفجر وقته ${fmt.format(prayerTimes.fajr)}، ');
        buffer.write('الظهر وقته ${fmt.format(prayerTimes.dhuhr)}، ');
        buffer.write('العصر وقته ${fmt.format(prayerTimes.asr)}، ');
        buffer.write('المغرب وقته ${fmt.format(prayerTimes.maghrib)}، ');
        buffer.write('العشاء وقته ${fmt.format(prayerTimes.isha)}.');
        return buffer.toString();
      },
    );
  }

  Future<String> _executeDiet(Map<String, String> params) async {
    final requestedMeal = params['meal']; // breakfast | lunch | dinner | snack | null

    // Derive BMI from the user's saved height/weight when available so the
    // plan matches their real recommended calorie band. Fall back to the
    // "normal" band (1800 kcal) when the profile is incomplete.
    final sp = await SharedPreferences.getInstance();
    final heightCm = sp.getDouble(StorageKeys.userHeightCm);
    final weightKg = sp.getDouble(StorageKeys.userWeightKg);

    BmiResult bmi;
    if (heightCm != null && weightKg != null && heightCm > 0 && weightKg > 0) {
      final value = weightKg / ((heightCm / 100) * (heightCm / 100));
      BmiCategory cat;
      int calories;
      if (value < 18.5) { cat = BmiCategory.underweight; calories = 2200; }
      else if (value < 25.0) { cat = BmiCategory.normal; calories = 1800; }
      else if (value < 30.0) { cat = BmiCategory.overweight; calories = 1500; }
      else { cat = BmiCategory.obese; calories = 1200; }
      bmi = BmiResult(
        value: double.parse(value.toStringAsFixed(1)),
        category: cat,
        recommendedCalories: calories,
      );
    } else {
      bmi = const BmiResult(
        value: 22.0,
        category: BmiCategory.normal,
        recommendedCalories: 1800,
      );
    }

    // Honour saved allergies (from the onboarding flow) and disliked foods.
    final allergiesJson = sp.getString(StorageKeys.userAllergies);
    List<String> allergies = const [];
    if (allergiesJson != null && allergiesJson.isNotEmpty) {
      try {
        allergies = (jsonDecode(allergiesJson) as List).cast<String>();
      } catch (_) {/* ignore malformed cache */}
    }
    final dislikedJson = sp.getString(StorageKeys.dislikedFoods);
    List<String> dislikedFoods = const [];
    if (dislikedJson != null && dislikedJson.isNotEmpty) {
      try {
        dislikedFoods = (jsonDecode(dislikedJson) as List).cast<String>();
      } catch (_) {/* ignore */}
    }

    // Advance a persistent cursor so consecutive voice "أكل" requests cycle
    // through different compatible meals instead of always returning the
    // same first match. The DietLocalDatasource uses this to shift which
    // meal gets picked per slot.
    final cursor = sp.getInt(StorageKeys.dietVoiceCursor) ?? 0;
    await sp.setInt(StorageKeys.dietVoiceCursor, cursor + 1);

    final result = await _getDietPlan(
      bmiResult: bmi,
      dislikedFoods: dislikedFoods,
      allergies: allergies,
      rotationIndex: cursor,
    );
    return result.fold(
      (failure) => 'عذرا، ما قدرت أجيب خطة الأكل.',
      (plan) {
        if (plan.meals.isEmpty) {
          return 'ما عندي اقتراحات للأكل حالياً. جرب تضيف تفضيلاتك أول.';
        }

        // If the user asked about a specific meal, answer that one.
        if (requestedMeal != null && requestedMeal.isNotEmpty) {
          final match = plan.meals.where(
            (m) => m.mealTime.name.toLowerCase() == requestedMeal,
          );
          final meal = match.isNotEmpty ? match.first : plan.meals.first;
          return 'اقتراح ${_mealNameArabic(requestedMeal)}: ${meal.nameAr}، '
              'تقريباً ${meal.calories} سعرة حرارية.';
        }

        // Otherwise read out the full day — breakfast, lunch, dinner — so
        // the user hears a complete plan instead of just one meal.
        final buf = StringBuffer('خطة الأكل اليوم: ');
        for (final slot in const [MealTime.breakfast, MealTime.lunch, MealTime.dinner]) {
          final matches = plan.meals.where((m) => m.mealTime == slot);
          if (matches.isEmpty) continue;
          final meal = matches.first;
          buf.write('${_mealNameArabic(slot.name)}: ${meal.nameAr} '
              '(${meal.calories} سعرة). ');
        }
        final totalCalories = plan.meals
            .where((m) => m.mealTime != MealTime.snack)
            .fold<int>(0, (s, m) => s + m.calories);
        buf.write('المجموع حوالي $totalCalories سعرة حرارية.');
        return buf.toString();
      },
    );
  }

  Future<String> _executeLocations(Map<String, String> params) async {
    final placeType = params['place_type'] ?? 'mosque';
    final placeNameArabic = _placeNameArabic(placeType);
    final category = _placeCategory(placeType);

    _autoListen = false;
    navigatorKey.currentState?.pushNamed('/locations', arguments: category);
    return 'ابشر! بفتح لك أقرب $placeNameArabic.';
  }

  Future<String> _executeQuran(Map<String, String> params) async {
    final surahName = params['surah'];
    final result = await _getSurahs();
    return result.fold(
      (failure) => 'عذرا، ما قدرت أشغل القرآن.',
      (surahs) {
        if (surahs.isEmpty) return 'عذرا، ما قدرت أشغل القرآن.';

        // No surah specified → open the Quran list page
        if (surahName == null) {
          _autoListen = false;
          navigatorKey.currentState?.pushNamed('/quran');
          return 'تفضل، اختر السورة اللي تبيها.';
        }

        // Fold letter variants on both the candidate and the stored names
        // so "الفاتحة" / "الفاتحه" / "فاتحه" / "فاتحة" all resolve to surah 1.
        // The canonical quran.json names use the ة form; STT output and the
        // normalised param don't, so strict == always failed for those.
        final looseTarget = _looseFoldArabic(surahName);
        final looseTargetNoAl = looseTarget.startsWith('ال')
            ? looseTarget.substring(2)
            : looseTarget;

        Surah? matched;
        for (final s in surahs) {
          final loose = _looseFoldArabic(s.arabicName);
          final looseNoAl =
              loose.startsWith('ال') ? loose.substring(2) : loose;
          if (loose == looseTarget ||
              looseNoAl == looseTargetNoAl ||
              loose == looseTargetNoAl ||
              looseNoAl == looseTarget) {
            matched = s;
            break;
          }
        }

        if (matched == null) {
          return 'عذرا، ما لقيت سورة $surahName. قول اسم السورة مرة ثانية.';
        }

        // Stop auto-listening — user is entering Quran reading mode
        _autoListen = false;

        // Hard-stop the TTS engine BEFORE we navigate. Otherwise the
        // conversation announcement keeps speaking while the reciter mp3
        // starts, and the user hears two voices at once. We fire-and-forget
        // because this branch is inside a synchronous Either.fold callback.
        _tts.stop();

        // Navigate to the Surah page and let THAT page's cubit start
        // playback once it has loaded the surah. We deliberately do NOT
        // call playCurrentAyah on a second IslamicCubit instance here —
        // doing so creates two simultaneous mp3 streams.
        navigatorKey.currentState?.pushNamed(
          '/surah-detail',
          arguments: {
            'surahId': matched.id,
            'autoplay': true,
          },
        );

        // Return an empty response so _respondAndListen does NOT speak
        // anything. The reciter audio on the Surah page is the feedback
        // the user needs.
        return '';
      },
    );
  }

  Future<String> _executeIslamicAdvice() async {
    // Rotate through the full catalog instead of returning the same entry
    // every call. The cursor persists across sessions so the user hears
    // fresh advice even after closing the app.
    //
    // Resolved lazily through GetIt rather than the cubit constructor so
    // adding/removing voice-layer usecases doesn't break hot reload.
    final getAdviceList = GetIt.instance<GetAdviceList>();
    final listResult = await getAdviceList();
    final list = listResult.fold<List<IslamicAdvice>>(
      (_) => const <IslamicAdvice>[],
      (l) => l,
    );
    if (listResult.isLeft()) return 'عذرا، ما قدرت أجيب نصيحة اليوم.';
    if (list.isEmpty) return 'ما عندي نصائح حالياً.';

    final sp = await SharedPreferences.getInstance();
    final cursor = sp.getInt(StorageKeys.adviceVoiceCursor) ?? 0;
    final advice = list[cursor % list.length];
    await sp.setInt(
      StorageKeys.adviceVoiceCursor,
      (cursor + 1) % list.length,
    );

    final buffer = StringBuffer(advice.arabicText);
    if (advice.source.isNotEmpty) {
      buffer.write(' — ${advice.source}');
    }
    return buffer.toString();
  }

  // ─── Device control ───────────────────────────────────────────────────────

  static const _kVolumeChannel = MethodChannel('com.rafeeq.app/volume');

  Future<String> _executeDeviceControl(Map<String, String> params) async {
    final action = params['action'] ?? '';
    switch (action) {
      case 'volume_up':
        await _invokeVolume('volumeUp');
        return 'تم رفع الصوت.';
      case 'volume_down':
        await _invokeVolume('volumeDown');
        return 'تم خفض الصوت.';
      case 'mute':
        await _invokeVolume('mute');
        return 'تم كتم الصوت.';
      case 'open_app':
        return await _openSocialApp(params['app_name'] ?? '');
      case 'set_alarm':
        return await _setDeviceAlarm(params);
      default:
        return 'ما فهمت الطلب. قل مثلاً: ارفع الصوت، أو افتح واتساب، أو اضبط منبه الساعة ثلاثة.';
    }
  }

  Future<void> _invokeVolume(String method) async {
    try {
      await _kVolumeChannel.invokeMethod(method);
    } catch (_) {
      // Best-effort — no crash if channel is unavailable
    }
  }

  Future<String> _openSocialApp(String appName) async {
    const schemeMap = <String, String>{
      'whatsapp': 'whatsapp://',
      'youtube': 'youtube://',
      'instagram': 'instagram://app',
      'telegram': 'tg://',
      'facebook': 'fb://',
      'tiktok': 'snssdk1233://',
      'twitter': 'twitter://',
    };
    const webMap = <String, String>{
      'whatsapp': 'https://web.whatsapp.com',
      'youtube': 'https://www.youtube.com',
      'instagram': 'https://www.instagram.com',
      'telegram': 'https://web.telegram.org',
      'facebook': 'https://www.facebook.com',
      'tiktok': 'https://www.tiktok.com',
      'twitter': 'https://twitter.com',
    };
    const displayMap = <String, String>{
      'whatsapp': 'واتساب',
      'youtube': 'يوتيوب',
      'instagram': 'إنستقرام',
      'telegram': 'تيليجرام',
      'facebook': 'فيسبوك',
      'tiktok': 'تيك توك',
      'twitter': 'تويتر',
    };

    final display = displayMap[appName] ?? appName;
    final scheme = schemeMap[appName];
    if (scheme == null) {
      return 'ما عرفت أي تطبيق تقصد. قل مثلاً: افتح واتساب أو افتح يوتيوب.';
    }

    try {
      final appUri = Uri.parse(scheme);
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return 'تم فتح $display.';
      }
      // App not installed — open in browser
      final webUrl = webMap[appName];
      if (webUrl != null) {
        await launchUrl(Uri.parse(webUrl),
            mode: LaunchMode.externalApplication);
        return 'تطبيق $display غير مثبت، تم فتحه في المتصفح.';
      }
      return 'تطبيق $display غير مثبت على الجهاز.';
    } catch (_) {
      return 'ما قدرت أفتح $display. تأكد أن التطبيق مثبت.';
    }
  }

  Future<String> _setDeviceAlarm(Map<String, String> params) async {
    if (!Platform.isAndroid) {
      return 'ضبط المنبه متاح حالياً على أجهزة أندرويد فقط.';
    }
    try {
      final hourStr = params['alarm_hour'];
      if (hourStr != null) {
        final hour = int.tryParse(hourStr) ?? 0;
        final minute = int.tryParse(params['alarm_minute'] ?? '0') ?? 0;
        final intent = AndroidIntent(
          action: 'android.intent.action.SET_ALARM',
          arguments: <String, dynamic>{
            'android.intent.extra.alarm.HOUR': hour,
            'android.intent.extra.alarm.MINUTES': minute,
            'android.intent.extra.alarm.MESSAGE': 'رفيق',
            'android.intent.extra.alarm.SKIP_UI': false,
          },
        );
        await intent.launch();
        final timeDisplay = _formatTimeArabic(
          DateTime(2000, 1, 1, hour, minute),
        );
        return 'يتم فتح الساعة لضبط المنبه $timeDisplay. تأكد من حفظه.';
      } else {
        // No time specified — open the alarms screen directly
        const intent = AndroidIntent(action: 'android.intent.action.SHOW_ALARMS');
        await intent.launch();
        return 'تم فتح تطبيق الساعة. اضبط المنبه اللي تبيه.';
      }
    } catch (_) {
      return 'ما قدرت أفتح تطبيق الساعة. افتحه يدوياً من الجهاز.';
    }
  }

  // ─── Dialect auto-detection ──────────────────────────────────────────────

  /// Runs the dialect detector on accumulated user text and persists the
  /// result to SharedPreferences so _buildSystemInstruction() uses the
  /// correct dialect for this same Gemini call.
  ///
  /// Fire-and-forget — we do NOT await this in _processSpeech so it never
  /// blocks the response pipeline.
  void _detectAndSaveDialect(String latestText) {
    Future(() async {
      // Try the latest utterance first so a dialect switch takes effect
      // immediately; fall back to the accumulator only when the single
      // utterance is too short to commit a confident result.
      final result = _dialectDetector.detect(latestText) ??
          _dialectDetector.detect(_accumulatedUserText);
      if (result == null) return;

      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString(StorageKeys.aiDialect) ?? 'najdi';

      if (current != result.dialect) {
        await prefs.setString(StorageKeys.aiDialect, result.dialect);
      }

      // Always push to UI — even if SharedPreferences already had this value,
      // the state field might be null (e.g. after resetChat).
      if (!isClosed && state.detectedDialect != result.dialect) {
        emit(state.copyWith(detectedDialect: result.dialect));
      }
    }).catchError((_) {});
  }

  /// Persists an API-returned dialect string and updates the UI badge.
  /// Fire-and-forget so it never blocks the response pipeline.
  void _applyApiDialect(String dialect) {
    Future(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorageKeys.aiDialect, dialect);
      if (!isClosed && state.detectedDialect != dialect) {
        emit(state.copyWith(detectedDialect: dialect));
      }
    }).catchError((_) {});
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _respondAndListen(String response, {bool clearFlow = false}) async {
    // Empty response is a signal from callers (e.g. Quran surah navigation)
    // that another audio source will take over and we MUST NOT speak
    // anything — otherwise TTS fights the reciter audio.
    final trimmed = response.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(
        status: ConversationStatus.idle,
        isSpeaking: false,
        clearFlow: clearFlow,
      ));
      return;
    }

    final botMsg = ConversationMessage(
      id: const Uuid().v4(),
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, botMsg],
      status: ConversationStatus.speaking,
      isSpeaking: true,
      clearFlow: clearFlow,
    ));

    final prefs = await SharedPreferences.getInstance();
    final voiceEnabled = prefs.getBool(StorageKeys.voiceFeedbackEnabled) ?? true;

    if (voiceEnabled) {
      await _tts.speak(response);
    } else {
      // Voice is muted — skip TTS and resume listening immediately
      if (!isClosed) {
        emit(state.copyWith(isSpeaking: false, status: ConversationStatus.idle));
        if (_autoListen) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!isClosed && !state.isListening) startListening();
          });
        }
        _autoListen = true;
      }
    }
  }

  /// Returns a canned, respectful Najdi-flavoured reply for short Saudi
  /// social/courtesy utterances. When the phrase is purely conversational
  /// (greeting, thanks, farewell, ماشاءالله, طفشان, …) we answer here
  /// instead of pushing it through intent detection — the user expects an
  /// immediate human-feeling response, not a routed action. Returns null
  /// when the utterance isn't a recognised social phrase, so the caller
  /// continues with normal intent classification.
  String? _handleSocialPhrase(String normalized) {
    bool has(String w) => normalized.contains(w);

    // ── "وش قلت" — repeat the last bot message ──────────────────────────────
    if (has('وش قلت') || has('ايش قلت') || has('وش قلتي') || has('عيد كلامك')) {
      for (int i = state.messages.length - 1; i >= 0; i--) {
        final m = state.messages[i];
        if (!m.isUser && m.text.trim().isNotEmpty) {
          return 'قلت لك: ${m.text}';
        }
      }
      return 'ما قلت شي بعد يا طويل العمر. تفضل، أنا أسمعك.';
    }

    // ── ماشاءالله ──────────────────────────────────────────────────────────
    if (has('ماشاءالله') || has('ماشاء الله') || has('ما شاء الله')) {
      return 'تبارك الله. اللهم بارك. الله يحفظك ويبارك في عمرك.';
    }

    // ── الحمد لله بخير / زين ──────────────────────────────────────────────
    if (has('أنا بخير الحمدلله') ||
        has('الحمد لله بخير') ||
        has('الحمدلله بخير') ||
        normalized.trim() == 'زين' ||
        has(' زين ') ||
        normalized.trim() == 'تمام') {
      return 'الحمد لله، الله يديم عليك الصحة والعافية يا طويل العمر.';
    }

    // ── Farewell ────────────────────────────────────────────────────────────
    if (has('فمان الله') ||
        has('في امان الله') ||
        has('فى امان الله') ||
        has('معسلامه') ||
        has('مع السلامه') ||
        has('مع السلامة')) {
      return 'في أمان الله ورعايته. الله يحفظك ويرعاك يا طويل العمر.';
    }

    // ── Thanks ──────────────────────────────────────────────────────────────
    if (has('تسلم ما قصرت') ||
        has('ما قصرت') ||
        has('تسلم') ||
        has('يعطيك العافيه') ||
        has('يعطيك العافية')) {
      return 'الله يسلمك ويعافيك. هذا واجبي، أنا في خدمتك دايم.';
    }

    // ── "اسلم وش بعد عندك" — what else do you have ─────────────────────────
    if (has('وش بعد عندك') || has('ايش بعد عندك') || has('وش عندك كمان')) {
      return 'أقدر أساعدك في أوقات الصلاة، أذكرك بدوياتك، أشغلك قرآن، '
          'أقولك دعاء أو نصيحة، أدلك على أقرب مسجد أو مستوصف، '
          'أو نسولف سوا. وش تبي؟';
    }

    // ── Greetings: شخبارك / علومك / كيفك دحين / اشبك اليوم / بشرني ─────────
    if (has('شخبارك') ||
        has('شخبارش') ||
        has('علومك') ||
        has('شلونك') ||
        has('كيفك دحين') ||
        has('كيف حالك') ||
        has('اشبك اليوم') ||
        has('شبك اليوم') ||
        has('بشرني عنك')) {
      return 'الحمد لله بخير وبأتم الصحة، الله يطول عمرك. وأنت كيفك اليوم؟';
    }

    // ── ابشر (alone or as a leading filler) ────────────────────────────────
    if (normalized.trim() == 'ابشر' ||
        normalized.startsWith('ابشر ') ||
        normalized.endsWith(' ابشر')) {
      // If "ابشر" came with extra text, let intent detection handle the rest
      if (normalized.trim() != 'ابشر' && normalized.split(' ').length > 2) {
        return null;
      }
      return 'حياك الله يا طويل العمر، تفضل قل اللي تبيه وأنا في خدمتك.';
    }

    // ── طفشان / مالي خلق ──────────────────────────────────────────────────
    if (has('طفشان') ||
        has('طفشانه') ||
        has('مالي خلق') ||
        has('ضايج') ||
        has('ضايقه') ||
        has('زهقان')) {
      return 'الله يونسك ويفرّح قلبك يا طويل العمر. '
          'تبي أقولك دعاء يريّحك، أو نسولف سوا، أو أشغّلك شي من القرآن؟';
    }

    // ── "اهرج معي" / "سولف معي" ─────────────────────────────────────────
    if (has('اهرج معي') ||
        has('سولف معي') ||
        has('سولفلي') ||
        has('كلمني شوي') ||
        has('تكلم معي')) {
      return 'ابشر يا طويل العمر، أنا معاك. وش تبي نتكلم عنه؟ '
          'تبي قصة، نكتة، شعر، ولا نسولف عن يومك؟';
    }

    // ── "قولي قصيدة / شعر" ─────────────────────────────────────────────────
    if (has('قصيده') ||
        has('قصيدة') ||
        has('قل شعر') ||
        has('قولي شعر') ||
        has('قول شعر') ||
        has('ابغى شعر') ||
        has('ابي شعر')) {
      return 'أبشر يا طويل العمر، أقولك أبيات وطنية:\n'
          'أنا السعودي، رايتي رمز الإسلام.\n'
          'وأنا العرب، واصل العروبة بلادي.\n'
          'وأنا سليل المجد من بدء الأيام.\n'
          'الناس تشهد لي ويشهد جهادي.\n'
          'دستوري القرآن، قانون ونظام.\n'
          'وسنّة نبي الله لنا خير هادي.';
    }


    return null;
  }

  bool _isCancelCommand(String text) {
    return text.contains('الغي') ||
        text.contains('الغاء') ||
        text.contains('خلاص') ||
        text.contains('وقف') ||
        text.contains('كنسل') ||
        text.contains('لا خلاص') ||
        text.contains('طنش');
  }

  String _normalizeForExtraction(String text) {
    var s = text.trim().toLowerCase();
    // Strip diacritics
    s = s.replaceAll(
      RegExp(
        r'[\u064B-\u065F\u0670\u0610-\u061A\u06D6-\u06DC'
        r'\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]',
      ),
      '',
    );
    s = s.replaceAll('ـ', '');
    // Normalize Arabic variants
    s = s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    // Normalize Arabic-Indic digits
    const digitMap = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    digitMap.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  ReminderType _inferReminderType(String title) {
    final t = title.toLowerCase();
    if (t.contains('دواء') || t.contains('حبوب') || t.contains('علاج')) {
      return ReminderType.medication;
    }
    if (t.contains('صلاة') || t.contains('اذان') || t.contains('فجر') ||
        t.contains('ظهر') || t.contains('عصر') || t.contains('مغرب') ||
        t.contains('عشاء')) {
      return ReminderType.prayer;
    }
    if (t.contains('موعد') || t.contains('دكتور') || t.contains('طبيب')) {
      return ReminderType.appointment;
    }
    if (t.contains('ماء') || t.contains('موية') || t.contains('اشرب')) {
      return ReminderType.hydration;
    }
    return ReminderType.custom;
  }

  String _formatTimeArabic(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    String period;
    int displayHour;

    if (hour < 12) {
      period = 'صباحًا';
      displayHour = hour == 0 ? 12 : hour;
    } else {
      period = 'مساءً';
      displayHour = hour == 12 ? 12 : hour - 12;
    }

    if (minute == 0) {
      return 'الساعة $displayHour $period';
    }
    return 'الساعة $displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _mealNameArabic(String meal) {
    switch (meal) {
      case 'breakfast': return 'الفطور';
      case 'lunch': return 'الغداء';
      case 'dinner': return 'العشاء';
      case 'snack': return 'وجبة خفيفة';
      default: return 'الوجبة';
    }
  }

  String _placeNameArabic(String type) {
    switch (type) {
      case 'mosque': return 'مسجد';
      case 'pharmacy': return 'صيدلية';
      case 'hospital': return 'مستشفى';
      case 'clinic': return 'عيادة';
      case 'restaurant': return 'مطعم';
      case 'park': return 'حديقة';
      default: return 'مكان';
    }
  }

  PlaceCategory _placeCategory(String type) {
    switch (type) {
      case 'mosque': return PlaceCategory.mosque;
      case 'pharmacy': return PlaceCategory.pharmacy;
      case 'hospital': return PlaceCategory.hospital;
      case 'clinic': return PlaceCategory.clinic;
      case 'restaurant': return PlaceCategory.restaurant;
      case 'park': return PlaceCategory.park;
      default: return PlaceCategory.mosque;
    }
  }

  /// Applies TTS pitch to match the selected voice gender.
  /// Call this whenever the user changes the voice type in settings.
  Future<void> applyVoiceType(String voiceType) async {
    final pitch = voiceType == 'male' ? 0.8 : 1.1;
    await _tts.setPitch(pitch);
  }

  /// Process a command that came from a UI tap (chip button) rather than voice.
  Future<void> processTappedCommand(String command) =>
      _processSpeech(command);

  // ─── Gemini & Reset ──────────────────────────────────────────────────────────

  /// Clears the conversation and stops any ongoing speech/listening.
  /// Backed by the "محادثة جديدة" button. Backend history (if written) is
  /// kept server-side for background context; the UI just starts empty.
  Future<void> resetChat() async {
    _autoListen = false;
    _geminiMode = false;
    _accumulatedUserText = '';
    await _tts.stop();
    await _speech.stop();
    emit(const ConversationState()); // detectedDialect resets to null here
  }

  /// Builds the system instruction for Gemini using the user's AI
  /// preferences saved in SharedPreferences (from the 3-question onboarding).
  /// Falls back to short + simple + examples when nothing is stored.
  Future<String> _buildSystemInstruction() async {
    final sp = await SharedPreferences.getInstance();
    final replyLength = sp.getString(StorageKeys.aiReplyLength) ?? 'short';
    final explanation = sp.getString(StorageKeys.aiExplanationStyle) ?? 'simple';
    final wantsExamples = sp.getBool(StorageKeys.aiWantsExamples) ?? true;
    final dialect = sp.getString(StorageKeys.aiDialect) ?? 'najdi';
    final userName = sp.getString(StorageKeys.userName) ?? '';
    final userAge = sp.getString(StorageKeys.userAge) ?? '';

    final dialectGuide = _dialectInstruction(dialect);

    final buf = StringBuffer()
      // ── Identity & audience ───────────────────────────────────────────────
      ..writeln('أنت "رفيق"، مساعد ذكي مخصص لكبار السن في المملكة العربية السعودية.')
      ..writeln(
          'المستخدم شخص كبير في السن يعيش في السعودية — تعامل معه باحترام، '
          'كأنك تكلم والدك أو جدك. استخدم "حيّاك الله" و"الله يعطيك العافية" '
          'و"يا طويل العمر" في كلامك بشكل طبيعي غير متكلف.');
    if (userName.isNotEmpty) {
      buf.writeln('اسم المستخدم: $userName. ناده باسمه أحيانًا.');
    }
    if (userAge.isNotEmpty) {
      buf.writeln('عمر المستخدم: $userAge سنة.');
    }

    buf
      // ── Dialect ────────────────────────────────────────────────────────────
      ..writeln(dialectGuide)
      ..writeln(
          'لا تخلط بين اللهجات، ولا تستخدم الفصحى إلا في الاقتباسات الدينية '
          '(آيات قرآنية أو أحاديث).')
      ..writeln('لا تستخدم رموز تعبيرية (emojis) ولا markdown ولا عناوين، '
          'الإجابة تُقرأ بصوت عالٍ.')
      ..writeln(
          'عند الحديث عن مقادير الأكل استخدم "ملاعق كبيرة" أو "ملاعق صغيرة" '
          'أو "كوب" بدلاً من الجرامات والأونصات.')

      // ── Allowed topics (elderly-focused) ──────────────────────────────────
      ..writeln('المواضيع المناسبة لك:')
      ..writeln(
          '- الصحة العامة، الأمراض الشائعة، الأدوية، الغذاء الصحي، النشاط البدني الخفيف.')
      ..writeln(
          '- الإسلام: الصلاة، القرآن، الدعاء، الحديث، الذكر، الحكمة الدينية.')
      ..writeln(
          '- الحياة اليومية: التذكيرات، المواعيد، العادات الصحية، النوم، الاسترخاء.')
      ..writeln(
          '- الأسرة والأحفاد والعلاقات الاجتماعية والدعم العاطفي.')
      ..writeln('- الطقس والجغرافيا ومعلومات عامة مناسبة.')

      // ── Strictly forbidden topics ─────────────────────────────────────────
      ..writeln('ممنوع منعاً تاماً الدخول في هذه المواضيع:')
      ..writeln(
          '- السياسة بكل أشكالها (حكومات، أحزاب، حروب، حكام، انتخابات، تصريحات سياسية).')
      ..writeln(
          '- الخلافات الطائفية أو المذهبية أو القومية أو القبلية.')
      ..writeln(
          '- الاستثمار والأسهم والعملات الرقمية والتوصيات المالية.')
      ..writeln(
          '- المحتوى العنيف أو المخيف أو الجنسي أو غير اللائق.')
      ..writeln('- الألعاب الإلكترونية والبرمجة والتقنية المعقدة.')
      ..writeln(
          'إذا سألك المستخدم عن أي موضوع ممنوع، لا تجاوب أبداً — '
          'رد بلطف: "هذا الموضوع ما هو من اختصاصي يا طويل العمر. '
          'خلنا نتكلم عن صحتك أو يومك أو أي شي يريحك."')

      // ── Communication style ────────────────────────────────────────────────
      ..writeln('تكلم بصبر وهدوء. إذا ما فهم المستخدم، أعد الشرح بكلمات أبسط.')
      ..writeln('ما تعطيه معلومات كثيرة دفعة وحدة — ركز على نقطة أو نقطتين فقط.')
      ..writeln(
          'في آخر كل رد، اسأله بنبرة ودودة: "تحتاج شي ثاني؟" أو "فيه شي أقدر أساعدك فيه؟" '
          'حتى يحس إنك معاه.');

    // ── Reply length & style ────────────────────────────────────────────────
    if (replyLength == 'long') {
      buf.writeln('أعط إجابة كاملة وواضحة، واشرح النقاط المهمة بتفصيل مناسب.');
    } else {
      buf.writeln('خلي إجابتك قصيرة جداً، في جملة أو جملتين فقط.');
    }

    if (explanation == 'detailed') {
      buf.writeln('تقدر تستخدم مصطلحات لما تحتاج، مع توضيحها ببساطة.');
    } else {
      buf.writeln('استخدم كلمات بسيطة جداً مفهومة لكبير السن، وتجنب المصطلحات.');
    }

    if (wantsExamples) {
      buf.writeln('أضف مثال واحد قصير واقعي يوضح فكرتك.');
    } else {
      buf.writeln('لا تضيف أمثلة إلا إذا طلبها المستخدم صراحة.');
    }

    return buf.toString().trim();
  }

  /// Returns a dialect-specific instruction block for Gemini.
  /// Keys match StorageKeys.aiDialect values — keep in sync with onboarding.
  String _dialectInstruction(String dialect) {
    switch (dialect) {
      case 'janoubi':
        return 'تحدث باللهجة الجنوبية السعودية (أبها، جازان، نجران). '
            'استخدم كلمات مثل "كيف حالش؟"، "يا ولدي"، "ابشر"، "والله"، '
            'واختم الكلمات أحيانًا بالشين مثل "كيفش" و"وينش".';
      case 'hijazi':
        return 'تحدث باللهجة الحجازية السعودية (جدة، مكة، المدينة). '
          'استخدم كلمات طبيعية وبسيطة مثل "ايش", "دحين", "تبغى", "ابشر", '
          'مع نبرة دافئة ومحترمة تناسب كبار السن.';
      case 'sharqawi':
        return 'تحدث باللهجة الشرقاوية (الدمام، الأحساء، القطيف). '
            'استخدم "شلونك"، "وش أخبارك"، "عاد"، "اي والله"، '
            'مع نغمة خليجية هادئة.';
      case 'najdi':
      default:
        return 'تحدث باللهجة النجدية السعودية (الرياض والقصيم). '
            'استخدم "كيفك"، "وش أخبارك"، "ابشر"، "الله يطول عمرك"، '
            'واختم بعض العبارات بالسين مثل "وينتس" و"كيف حالس".';
    }
  }

  /// Sends [prompt] to Gemini 1.5 Flash, appends the reply as a bot message,
  /// and reads it aloud via TTS.
  Future<void> askGemini(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    // User message is already in the chat (added by _processSpeech before
    // routing here). Just switch to processing state.
    emit(state.copyWith(
      status: ConversationStatus.processing,
      clearFlow: true,
    ));

    try {
      final dio = Dio();
      final systemInstruction = await _buildSystemInstruction();
      print('[Gemini] Sending prompt: $trimmed');
      print('[Gemini] Using API key: ${AppConstants.geminiApiKey}');

      final response = await dio.post(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent',
        queryParameters: {'key': AppConstants.geminiApiKey},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'system_instruction': {
            'parts': [
              {'text': systemInstruction}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': trimmed}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 512,
          },
        },
      );

      print('[Gemini] Status: ${response.statusCode}');
      print('[Gemini] Response body: ${response.data}');

      final answer =
          (response.data['candidates'] as List).first['content']['parts'][0]
              ['text'] as String;

      print('[Gemini] Extracted answer: $answer');

      final botMsg = ConversationMessage(
        id: const Uuid().v4(),
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
      );
      emit(state.copyWith(
        messages: [...state.messages, botMsg],
        status: ConversationStatus.speaking,
        isSpeaking: true,
      ));
      _autoListen = true; // keep listening for next Gemini question
      final geminiPrefs = await SharedPreferences.getInstance();
      if (geminiPrefs.getBool(StorageKeys.voiceFeedbackEnabled) ?? true) {
        await _tts.speak(answer);
      } else {
        if (!isClosed) {
          emit(state.copyWith(isSpeaking: false, status: ConversationStatus.idle));
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!isClosed && !state.isListening) startListening();
          });
        }
      }
    } catch (e, stack) {
      print('[Gemini] ERROR: $e');
      print('[Gemini] Stack: $stack');
      if (e is DioException) {
        print('[Gemini] DioException type: ${e.type}');
        print('[Gemini] DioException status: ${e.response?.statusCode}');
        print('[Gemini] DioException response: ${e.response?.data}');
      }
      const errorText =
          'عذراً، ما قدرت أتصل بالمساعد الذكي. تأكد من الاتصال بالإنترنت.';
      final errMsg = ConversationMessage(
        id: const Uuid().v4(),
        text: errorText,
        isUser: false,
        timestamp: DateTime.now(),
      );
      emit(state.copyWith(
        messages: [...state.messages, errMsg],
        status: ConversationStatus.idle,
      ));
    }
  }

  /// Prompts the user verbally then routes the next speech input to Gemini.
  Future<void> activateGeminiVoice() async {
    _geminiMode = true;
    _autoListen = true;
    await stopListening();
    // Speak the prompt; TTS completion handler will auto-start listening.
    await _respondAndListen('تفضل، ماذا تريد أن تسأل جيميني؟');
  }

  // ── Keyword helpers ─────────────────────────────────────────────────────────

  bool _isGeminiKeyword(String normalized) =>
      normalized.contains('جيميني') ||
      normalized.contains('جيمني') ||
      normalized.contains('جيمينى');

  /// Extracts the question that follows the Gemini keyword in the utterance.
  String _extractGeminiQuestion(String original, String normalized) {
    for (final kw in ['جيميني', 'جيمني', 'جيمينى']) {
      final idx = normalized.indexOf(kw);
      if (idx >= 0) {
        final after = original.substring(idx + kw.length).trim();
        if (after.isNotEmpty) return after;
      }
    }
    return '';
  }

  bool _isResetKeyword(String normalized) =>
      normalized.contains('محادثه جديده') ||
      normalized.contains('محادثة جديدة') ||
      normalized.contains('ابدا من جديد') ||
      normalized.contains('امسح المحادثه') ||
      normalized.contains('مسح المحادثه') ||
      normalized.contains('شات جديد');

  // ─── State helpers ───────────────────────────────────────────────────────────

  void clearIntent() => emit(state.copyWith(clearIntent: true));

  void clearNavRoute() => emit(state.copyWith(clearNavRoute: true));

  void cancelFlow() {
    emit(state.copyWith(clearFlow: true));
  }

  @override
  Future<void> close() {
    _speech.stop();
    _tts.stop();
    // End the Firestore session best-effort
    final sid = _sessionId;
    if (sid != null) _remoteDs.endSession(sid).catchError((_) {});
    return super.close();
  }
}
