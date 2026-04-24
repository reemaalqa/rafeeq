import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../settings/data/datasources/settings_remote_datasource.dart';

/// Three-question onboarding shown right after the first successful login.
///
/// Questions (in Arabic, elderly-friendly big buttons):
///   1. تبغى الرد يكون قصير ولا طويل؟
///   2. تبغى الشرح بسيط ولا مفصّل؟
///   3. تبغى أمثلة ولا لا؟
///
/// Answers are PUT to /users/preferences which also flips
/// `preferences_onboarded` to true, so the user sees this screen only once.
class PreferencesOnboardingPage extends StatefulWidget {
  const PreferencesOnboardingPage({super.key});

  @override
  State<PreferencesOnboardingPage> createState() =>
      _PreferencesOnboardingPageState();
}

class _PreferencesOnboardingPageState extends State<PreferencesOnboardingPage> {
  String? _replyLength;      // "short" | "long"
  String? _explanationStyle; // "simple" | "detailed"
  bool? _wantsExamples;
  String? _dialect;          // "najdi" | "janoubi" | "shamali" | "sharqawi"
  bool _submitting = false;
  bool _checking = true;

  bool get _ready =>
      _replyLength != null &&
      _explanationStyle != null &&
      _wantsExamples != null &&
      _dialect != null;

  @override
  void initState() {
    super.initState();
    _skipIfAlreadyOnboarded();
  }

  /// Returning users (logout → login) must not see this screen again.
  /// Reads the local cache first (fast path); if absent, does not block —
  /// the user can still fill it in or hit "تخطي".
  Future<void> _skipIfAlreadyOnboarded() async {
    final sp = await SharedPreferences.getInstance();
    final done = sp.getBool(StorageKeys.preferencesOnboarded) ?? false;
    if (!mounted) return;
    if (done) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    setState(() => _checking = false);
  }

  Future<void> _submit() async {
    if (!_ready || _submitting) return;
    setState(() => _submitting = true);
    try {
      final ds = GetIt.instance<SettingsRemoteDataSource>();
      await ds.updateUserPreferences({
        'reply_length': _replyLength,
        'explanation_style': _explanationStyle,
        'wants_examples': _wantsExamples,
        'dialect': _dialect,
      });
      // Cache locally so the Gemini prompt builder can read it synchronously.
      final sp = await SharedPreferences.getInstance();
      await sp.setString(StorageKeys.aiReplyLength, _replyLength!);
      await sp.setString(StorageKeys.aiExplanationStyle, _explanationStyle!);
      await sp.setBool(StorageKeys.aiWantsExamples, _wantsExamples!);
      await sp.setString(StorageKeys.aiDialect, _dialect!);
      await sp.setBool(StorageKeys.preferencesOnboarded, true);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ما قدرنا نحفظ التفضيلات. حاول مرة ثانية.',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'تفضيلاتك',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _skip,
              child: const Text(
                'تخطي',
                style: TextStyle(fontSize: AppTheme.fontBody1),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppTheme.spaceMD),
                const Text(
                  'ساعدنا نعرف شلون تحب الردود 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontH2,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                const Text(
                  'تقدر تغيّرها لاحقًا من الإعدادات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody2,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXL),
                _Question(
                  emoji: '💬',
                  title: 'تبغى الرد يكون:',
                  optionA: const _Option(label: 'قصير', value: 'short'),
                  optionB: const _Option(label: 'طويل', value: 'long'),
                  selectedValue: _replyLength,
                  onSelect: (v) => setState(() => _replyLength = v),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                _Question(
                  emoji: '📖',
                  title: 'تبغى الشرح:',
                  optionA: const _Option(label: 'بسيط', value: 'simple'),
                  optionB: const _Option(label: 'مفصّل', value: 'detailed'),
                  selectedValue: _explanationStyle,
                  onSelect: (v) => setState(() => _explanationStyle = v),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                _Question(
                  emoji: '💡',
                  title: 'تحب نعطيك أمثلة؟',
                  optionA: const _Option(label: 'نعم', value: 'yes'),
                  optionB: const _Option(label: 'لا', value: 'no'),
                  selectedValue: _wantsExamples == null
                      ? null
                      : (_wantsExamples! ? 'yes' : 'no'),
                  onSelect: (v) =>
                      setState(() => _wantsExamples = v == 'yes'),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                _DialectPicker(
                  selectedValue: _dialect,
                  onSelect: (v) => setState(() => _dialect = v),
                ),
                const SizedBox(height: AppTheme.spaceXL),
                ElevatedButton(
                  onPressed: _ready && !_submitting ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('حفظ والبدء'),
                ),
                const SizedBox(height: AppTheme.spaceLG),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final String value;
  const _Option({required this.label, required this.value});
}

class _Question extends StatelessWidget {
  final String emoji;
  final String title;
  final _Option optionA;
  final _Option optionB;
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  const _Question({
    required this.emoji,
    required this.title,
    required this.optionA,
    required this.optionB,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: AppTheme.fontH3,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(
          children: [
            Expanded(
              child: _AnswerButton(
                label: optionA.label,
                selected: selectedValue == optionA.value,
                onTap: () => onSelect(optionA.value),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: _AnswerButton(
                label: optionB.label,
                selected: selectedValue == optionB.value,
                onTap: () => onSelect(optionB.value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialectPicker extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String> onSelect;

  const _DialectPicker({
    required this.selectedValue,
    required this.onSelect,
  });

  static const _dialects = [
    ('najdi',    'نجدية',    'الرياض والقصيم'),
    ('janoubi',  'جنوبية',  'أبها وجازان'),
    ('shamali',  'شمالية',  'حائل وتبوك'),
    ('sharqawi', 'شرقاوية', 'الدمام والأحساء'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('🗣️', style: TextStyle(fontSize: 32)),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                'وش لهجتك؟',
                style: const TextStyle(
                  fontSize: AppTheme.fontH3,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMD),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppTheme.spaceMD,
          crossAxisSpacing: AppTheme.spaceMD,
          childAspectRatio: 2.2,
          children: _dialects.map((d) {
            final selected = selectedValue == d.$1;
            return InkWell(
              onTap: () => onSelect(d.$1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryColor : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.$2,
                      style: TextStyle(
                        fontSize: AppTheme.fontBody1,
                        fontWeight: FontWeight.bold,
                        color:
                            selected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.$3,
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption,
                        color: selected
                            ? Colors.white.withOpacity(0.85)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 72,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontH3,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
