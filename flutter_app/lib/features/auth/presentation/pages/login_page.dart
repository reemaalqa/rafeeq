import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme_config.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late AnimationController _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _sendVerificationCode() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().sendVerificationCode(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: AppTheme.errorColor),
          );
        }
        if (state.status == AuthStatus.codeSent) {
          Navigator.pushNamed(context, '/verification', arguments: state.email);
        }
      },
      builder: (context, state) {
        final isLoading = state.status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.darkBackground,
                    AppTheme.darkSurface,
                  ]
                : [
                    AppTheme.primaryColor.withOpacity(0.05),
                    AppTheme.secondaryColor.withOpacity(0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: _fadeAnimation == null || _slideAnimation == null
                ? const SizedBox.shrink()
                : FadeTransition(
              opacity: _fadeAnimation!,
              child: SlideTransition(
                position: _slideAnimation!,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppTheme.spaceXXL * 1.5),
                      
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceLG),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 80,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spaceXL),
                      
                      Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: AppTheme.spaceSM),
                      
                      Text(
                        l10n.welcomeMessage,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: AppTheme.spaceXXL),
                      
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceLG),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _emailController,
                              label: l10n.email,
                              hint: l10n.emailHint,
                              keyboardType: TextInputType.emailAddress,
                              validator: AppValidators.validateEmail,
                              prefixIcon: const Icon(Icons.email_outlined),
                            ),

                            const SizedBox(height: AppTheme.spaceLG),

                            AppButton(
                              text: l10n.sendCode,
                              onPressed: isLoading ? null : _sendVerificationCode,
                              isLoading: isLoading,
                              icon: Icons.arrow_forward,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spaceLG),
                      
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMD),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: AppTheme.infoColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.infoColor, size: 28),
                            const SizedBox(width: AppTheme.spaceMD),
                            Expanded(
                              child: Text(
                                l10n.checkEmail,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
      }, // builder
    ); // BlocConsumer
  }
}
