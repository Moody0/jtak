import 'package:flutter_test/flutter_test.dart';
import 'package:jtek_app/src/core/services/authentication_service.dart';

void main() {
  group('AuthenticationService session validation', () {
    test('accepts only a real non-empty access token', () {
      expect(
          AuthenticationService.isUsableAccessToken('real.jwt.token'), isTrue);
      expect(AuthenticationService.isUsableAccessToken(null), isFalse);
      expect(AuthenticationService.isUsableAccessToken(''), isFalse);
      expect(AuthenticationService.isUsableAccessToken('   '), isFalse);
      expect(
        AuthenticationService.isUsableAccessToken('auth_jwt_token_legacy'),
        isFalse,
      );
      expect(
        AuthenticationService.isUsableAccessToken('live_user_token_fake'),
        isFalse,
      );
    });
  });

  group('AuthenticationService profile completion', () {
    test('requires a real customer name', () {
      expect(AuthenticationService.isIncompleteProfileName(null), isTrue);
      expect(AuthenticationService.isIncompleteProfileName(''), isTrue);
      expect(
          AuthenticationService.isIncompleteProfileName('عميل جيتك'), isTrue);
      expect(
          AuthenticationService.isIncompleteProfileName('مستخدم جيتك'), isTrue);
      expect(
          AuthenticationService.isIncompleteProfileName('عميل جتاك'), isTrue);
      expect(
          AuthenticationService.isIncompleteProfileName('مستخدم جتاك'), isTrue);
      expect(
          AuthenticationService.isIncompleteProfileName('محمد أحمد'), isFalse);
    });
  });
}
