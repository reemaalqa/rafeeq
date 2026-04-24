import 'package:equatable/equatable.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/detected_intent.dart';

enum ConversationStatus { idle, listening, processing, speaking, error }

class ConversationState extends Equatable {
  final List<ConversationMessage> messages;
  final bool isListening;
  final bool isSpeaking;
  final DetectedIntent? detectedIntent;
  final ConversationStatus status;
  final String? errorMessage;

  /// Live transcription text shown while the user is speaking.
  final String partialText;

  /// Dialect auto-detected from the user's accumulated speech.
  /// One of: 'najdi' | 'janoubi' | 'shamali' | 'sharqawi' | null.
  final String? detectedDialect;

  /// When non-null, the UI should navigate to this named route.
  final String? pendingNavRoute;

  /// Optional structured arguments to pass to the pending route.
  final Map<String, dynamic>? pendingNavArgs;

  // ── Multi-turn flow tracking ────────────────────────────────────────────────

  /// The intent type of the active flow, or null if no flow is in progress.
  final IntentType? activeFlowIntent;

  /// Slots collected so far for the active flow. Keys are slot names.
  final Map<String, String> collectedSlots;

  /// The key of the slot currently being asked for.
  final String? currentSlotKey;

  /// When non-null, the voice action was completed and this is the result message.
  final String? actionResult;

  const ConversationState({
    this.messages = const [],
    this.isListening = false,
    this.isSpeaking = false,
    this.detectedIntent,
    this.status = ConversationStatus.idle,
    this.errorMessage,
    this.partialText = '',
    this.detectedDialect,
    this.pendingNavRoute,
    this.pendingNavArgs,
    this.activeFlowIntent,
    this.collectedSlots = const {},
    this.currentSlotKey,
    this.actionResult,
  });

  bool get hasActiveFlow => activeFlowIntent != null;

  ConversationState copyWith({
    List<ConversationMessage>? messages,
    bool? isListening,
    bool? isSpeaking,
    DetectedIntent? detectedIntent,
    ConversationStatus? status,
    String? errorMessage,
    String? partialText,
    String? detectedDialect,
    bool clearDialect = false,
    String? pendingNavRoute,
    Map<String, dynamic>? pendingNavArgs,
    bool clearNavRoute = false,
    bool clearIntent = false,
    IntentType? activeFlowIntent,
    bool clearFlow = false,
    Map<String, String>? collectedSlots,
    String? currentSlotKey,
    bool clearCurrentSlot = false,
    String? actionResult,
    bool clearActionResult = false,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      detectedIntent: clearIntent ? null : (detectedIntent ?? this.detectedIntent),
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      partialText: partialText ?? this.partialText,
      detectedDialect: clearDialect ? null : (detectedDialect ?? this.detectedDialect),
      pendingNavRoute:
          clearNavRoute ? null : (pendingNavRoute ?? this.pendingNavRoute),
      pendingNavArgs: clearNavRoute ? null : (pendingNavArgs ?? this.pendingNavArgs),
      activeFlowIntent:
          clearFlow ? null : (activeFlowIntent ?? this.activeFlowIntent),
      collectedSlots:
          clearFlow ? const {} : (collectedSlots ?? this.collectedSlots),
      currentSlotKey:
          clearFlow || clearCurrentSlot
              ? null
              : (currentSlotKey ?? this.currentSlotKey),
      actionResult:
          clearActionResult ? null : (actionResult ?? this.actionResult),
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isListening,
        isSpeaking,
        detectedIntent,
        status,
        errorMessage,
        partialText,
        detectedDialect,
        pendingNavRoute,
        pendingNavArgs,
        activeFlowIntent,
        collectedSlots,
        currentSlotKey,
        actionResult,
      ];
}
