import 'package:flutter_test/flutter_test.dart';
import 'package:app_jtak_delivery/src/core/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery Location Service & Startup Safety Suite', () {
    test('LocationAccessIssue enum supports standard issues', () {
      expect(LocationAccessIssue.values.contains(LocationAccessIssue.serviceDisabled), isTrue);
      expect(LocationAccessIssue.values.contains(LocationAccessIssue.permissionDenied), isTrue);
      expect(LocationAccessIssue.values.contains(LocationAccessIssue.permissionDeniedForever), isTrue);
    });

    test('LocationAccessException formats message correctly', () {
      final ex = LocationAccessException(LocationAccessIssue.serviceDisabled, 'Location service is disabled');
      expect(ex.toString(), equals('Location service is disabled'));
      expect(ex.issue, equals(LocationAccessIssue.serviceDisabled));
    });
  });
}
