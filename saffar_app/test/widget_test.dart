import 'package:flutter_test/flutter_test.dart';
import 'package:saffar_app/core/services/validator_service.dart';

void main() {
  group('ValidatorService Unit Tests', () {
    late ValidatorService validatorService;

    setUp(() {
      validatorService = ValidatorService();
    });

    test('Validates customer and driver names', () {
      expect(validatorService.validateName('Sameer Verma'), isTrue);
      expect(validatorService.validateName(''), isFalse);
    });

    test('Validates 10-digit mobile phone numbers', () {
      expect(validatorService.validatePhone('9876543210'), isTrue);
      expect(validatorService.validatePhone('987654321'), isFalse); // 9 digits
      expect(validatorService.validatePhone('98765432100'), isFalse); // 11 digits
      expect(validatorService.validatePhone('987654abcd'), isFalse); // non-numeric
    });

    test('Validates email addresses', () {
      expect(validatorService.validateEmail('sameer.v@example.com'), isTrue);
      expect(validatorService.validateEmail('invalid-email'), isFalse);
      expect(validatorService.validateEmail('@missingusername.com'), isFalse);
    });

    test('Validates password length (at least 8 characters)', () {
      expect(validatorService.validatePassword('secret123'), isTrue);
      expect(validatorService.validatePassword('short'), isFalse);
    });
  });
}
