import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/game_text_field.dart';
import '../data/auth_repository.dart';
import 'after_auth.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'validators.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/social_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<AppUser> Function() action) async {
    setState(() => _loading = true);
    try {
      final user = await action();
      if (!mounted) return;
      await continueAfterAuth(context, user);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _run(
      () => authRepository.signInWithEmail(_email.text.trim(), _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back 👋',
      subtitle: 'Your streak is waiting. Log in to keep it alive.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                GameTextField(
                  controller: _email,
                  hint: 'Email',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                GameTextField(
                  controller: _password,
                  hint: 'Password',
                  icon: Icons.lock_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GameButton(label: 'Log in', loading: _loading, onPressed: _submit),
        const SizedBox(height: 24),
        const OrDivider(),
        const SizedBox(height: 24),
        SocialButtons(
          onGoogle: _loading
              ? null
              : () => _run(authRepository.signInWithGoogle),
          onApple: _loading ? null : () => _run(authRepository.signInWithApple),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New here?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text(
                'Create account',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
