class Validators {
  Validators._();

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _username = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v.trim())) return 'That email looks off';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    if (v.length < 8) return 'At least 8 characters';
    return null;
  }

  static String? required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? 'Enter your $field' : null;

  static String? username(String? v) {
    if (v == null || v.isEmpty) return 'Pick a username';
    if (!_username.hasMatch(v)) return '3–20 letters, numbers or _';
    return null;
  }

  /// 0–4 score used by the strength meter.
  static int passwordStrength(String v) {
    var score = 0;
    if (v.length >= 8) score++;
    if (v.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v) && RegExp(r'[^A-Za-z0-9]').hasMatch(v)) {
      score++;
    }
    return score;
  }
}
