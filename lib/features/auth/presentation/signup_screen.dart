import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/game_text_field.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';
import 'after_auth.dart';
import 'validators.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/social_buttons.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  int _strength = 0;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
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
      () => authRepository.signUpWithEmail(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your player',
      subtitle: 'Start at 1000 rating. Climb from there.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameTextField(
                  controller: _name,
                  hint: 'Full name',
                  icon: Icons.person_rounded,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => Validators.required(v, 'name'),
                ),
                const SizedBox(height: 14),
                GameTextField(
                  controller: _username,
                  hint: 'Username',
                  icon: Icons.sports_esports_rounded,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: Validators.username,
                ),
                const SizedBox(height: 14),
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
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  onChanged: (v) => setState(
                    () => _strength = Validators.passwordStrength(v),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 10),
                _StrengthMeter(score: _strength),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GameButton(
          label: 'Create account',
          loading: _loading,
          onPressed: _submit,
        ),
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
              'Already playing?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                'Log in',
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

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score});

  final int score;

  static const _labels = ['Too weak', 'Weak', 'Okay', 'Strong', 'Legendary'];
  static const _colors = [
    AppColors.notStudied,
    AppColors.misconception,
    AppColors.weak,
    AppColors.mastered,
    AppColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[score];
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: i < score ? color : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            _labels[score],
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
