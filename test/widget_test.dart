import 'package:aradhya/features/auth/presentation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email validator', () {
    expect(Validators.email('a@b.co'), isNull);
    expect(Validators.email('nope'), isNotNull);
    expect(Validators.email(''), isNotNull);
  });

  test('password strength scales with complexity', () {
    expect(Validators.passwordStrength('abc'), 0);
    expect(Validators.passwordStrength('abcdefgh'), 1);
    expect(Validators.passwordStrength('Abcdefgh1!xyz'), 4);
  });
}
