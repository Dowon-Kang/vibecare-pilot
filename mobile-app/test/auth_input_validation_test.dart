import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/services/auth_input_validation.dart';

void main() {
  test('signup requires a valid email and matching password confirmation', () {
    expect(validateAuthEmail(''), isNotNull);
    expect(validateAuthEmail('not-an-email'), isNotNull);
    expect(validateAuthEmail('member@example.com'), isNull);
    expect(validateAuthPassword('12345'), isNotNull);
    expect(validateAuthPassword('123456'), isNull);
    expect(validatePasswordConfirmation('123456', '1234567'), isNotNull);
    expect(validatePasswordConfirmation('123456', '123456'), isNull);
  });
}
