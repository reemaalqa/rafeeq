import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class VerificationPage extends StatefulWidget {
  final String email;

  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _resendTimer = 30;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _verifyCode() {
    if (_code.length == 6) {
      context.read<AuthCubit>().verifyOtp(widget.email, _code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: AppTheme.errorColor),
          );
        }
        if (state.status == AuthStatus.authenticated) {
          // Route new users to the 3-question AI preferences onboarding.
          // That page itself skips forward to /home if the backend says
          // preferences_onboarded is already true.
          Navigator.pushReplacementNamed(context, '/preferences-onboarding');
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spaceLG),
              
              Text(
                l10n.verificationCode,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spaceMD),
              
              Text(
                l10n.checkEmail,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spaceSM),
              
              Text(
                widget.email,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spaceXL),
              
              // Code Input Fields — always LTR regardless of app locale
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: Theme.of(context).textTheme.displaySmall,
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_code.length == 6) {
                          _verifyCode();
                        }
                      },
                    ),
                  );
                }),
              ),
              ),
              
              const SizedBox(height: AppTheme.spaceXL),
              
              AppButton(
                text: l10n.verifyCode,
                onPressed: (_code.length == 6 && !isLoading) ? _verifyCode : null,
                isLoading: isLoading,
                icon: Icons.check_circle_outline,
              ),
              
              const SizedBox(height: AppTheme.spaceLG),
              
              TextButton(
                onPressed: _resendTimer == 0 ? () {} : null,
                child: Text(
                  _resendTimer > 0
                      ? '${l10n.resendCode} (0:${_resendTimer.toString().padLeft(2, '0')})'
                      : l10n.resendCode,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
      }, // builder
    ); // BlocConsumer
  }
}
