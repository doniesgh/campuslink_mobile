import 'package:campuspulse/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notEmpty', () {
    expect(Validators.notEmpty('  ', 'Required'), 'Required');
    expect(Validators.notEmpty(null, 'Required'), 'Required');
    expect(Validators.notEmpty('211JMT0428', 'Required'), isNull);
  });

  test('email', () {
    expect(Validators.email('sarra.kefi@esprit.tn'), isNull);
    expect(Validators.email(' sarra.kefi@esprit.tn '), isNull);
    expect(Validators.email(''), 'Enter your email');
    expect(Validators.email('sarra.kefi'), 'Enter a valid email');
  });

  test('newPassword needs 8 characters', () {
    expect(Validators.newPassword('1234567'), isNotNull);
    expect(Validators.newPassword('12345678'), isNull);
  });

  test('code needs exactly 6 digits', () {
    expect(Validators.code('123456'), isNull);
    expect(Validators.code('12345'), isNotNull);
    expect(Validators.code('12a456'), isNotNull);
  });
}
