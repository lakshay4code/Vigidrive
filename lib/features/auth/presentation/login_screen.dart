import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../../shell/main_shell.dart';
import '../../systems/services/systems_repository.dart';
import '../../violations/services/violations_repository.dart';

/// Clean, professional, and institutional login screen for VigiDrive.
class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  final SystemsRepository? systemsRepository;
  final ViolationsRepository? violationsRepository;

  const LoginScreen({
    super.key,
    this.authService,
    this.systemsRepository,
    this.violationsRepository,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  late final AuthService _authService;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = FirebaseService.resolveAuthService(custom: widget.authService);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    // Dismiss soft keyboard
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        AuthCredentials(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            authService: _authService,
            systemsRepository: FirebaseService.resolveSystemsRepository(
              custom: widget.systemsRepository,
            ),
            violationsRepository: widget.violationsRepository ??
                FirebaseService.resolveViolationsRepository(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e is AuthException
          ? e.message
          : (e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Authentication failed. Please check your credentials.');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.errorLight,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(
              color: AppColors.error,
              width: 1.0,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: AppColors.borderSubtle,
                width: 1.0,
              ),
            ),
            title: const Text(
              AppStrings.forgotPassword,
              style: AppTypography.headingMedium,
            ),
            content: const Text(
              'Please provide your registered email address to receive password reset instructions.',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: AppColors.borderSubtle,
                width: 1.0,
              ),
            ),
            title: const Text(
              AppStrings.forgotPassword,
              style: AppTypography.headingMedium,
            ),
            content: Text(
              'Password reset instructions have been sent to $email.',
              style: AppTypography.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e is AuthException
          ? e.message
          : (e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Failed to send password reset email. Please try again.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.errorLight,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.error, width: 1.0),
          ),
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emailRequired;
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return AppStrings.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.passwordRequired;
    }
    if (value.length < 6) {
      return AppStrings.passwordMinLength;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 76,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 64,
                            color: AppColors.primaryDark,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // App Title
                    const Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: AppTypography.headingLarge,
                    ),
                    const SizedBox(height: 4),

                    // App Tagline / Institutional Subtitle
                    const Text(
                      AppStrings.appTagline,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: 36),

                    // Email Input Field
                    CustomTextField(
                      label: AppStrings.emailLabel,
                      hintText: AppStrings.emailHint,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: _validateEmail,
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocusNode);
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Input Field
                    CustomTextField(
                      label: AppStrings.passwordLabel,
                      hintText: AppStrings.passwordHint,
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline,
                      validator: _validatePassword,
                      onFieldSubmitted: (_) => _handleSignIn(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Forgot Password Link Action
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        child: const Text(
                          AppStrings.forgotPassword,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign In Button
                    CustomButton(
                      text: AppStrings.signInButton,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleSignIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
