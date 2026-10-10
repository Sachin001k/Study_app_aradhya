import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/game_text_field.dart';
import '../data/auth_repository.dart';
import 'validators.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await authRepository.sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return AuthScaffold(
        title: 'Check your inbox 📬',
        subtitle: 'We sent a reset link to ${_email.text.trim()}.',
        children: [
          GameButton(
            label: 'Back to log in',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
    return AuthScaffold(
      title: 'Lost your key?',
      subtitle: 'Enter your email and we\'ll send you a reset link.',
      children: [
        Form(
          key: _formKey,
          child: GameTextField(
            controller: _email,
            hint: 'Email',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 24),
        GameButton(
          label: 'Send reset link',
          loading: _loading,
          color: AppColors.secondary,
          shadowColor: AppColors.secondaryShadow,
          textColor: AppColors.textPrimary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
