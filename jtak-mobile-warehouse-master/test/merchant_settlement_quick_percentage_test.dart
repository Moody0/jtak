import 'package:app_jtak_warehouse/src/core/controllers/transactions_provider.dart';
import 'package:app_jtak_warehouse/src/core/services/authentication_service.dart';
import 'package:app_jtak_warehouse/src/core/services/locator.dart';
import 'package:app_jtak_warehouse/src/ui/pages/transaction/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (!locator.isRegistered<AuthenticationService>()) {
      setupLocator();
    }
  });

  Widget createTestWidget({required double availableBalance, ThemeData? theme}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TransactionsProvider>(create: (_) => TransactionsProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SettlementRequestSheet(availableBalance: availableBalance),
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('Merchant Settlement UI — Selected Percentage Button State Tests', () {
    testWidgets('1 & 4. Initial state: with available balance 2,250, 100% is selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '2250');

      // 100% chip has check icon and active state
      expect(find.text('كامل الرصيد (100%)'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('2. Tap 50%: amount becomes 1,125 and only 50% is selected', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '1125');
    });

    testWidgets('1. Tap 25%: amount becomes 563 and only 25% is selected', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('25%'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      // 2250 * 0.25 = 562.5 -> rounded to 563 SYP
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '563');
    });

    testWidgets('3. Tap 75%: amount becomes 1,688 and only 75% is selected', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('75%'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      // 2250 * 0.75 = 1687.5 -> rounded to 1688 SYP
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '1688');
    });

    testWidgets('4. Tap 100%: amount becomes 2,250 and only 100% is selected', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byType(TextField).first) as TextField).controller?.text, '1125');

      await tester.tap(find.text('كامل الرصيد (100%)'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byType(TextField).first) as TextField).controller?.text, '2250');
    });

    testWidgets('5 & 6. Manual edit: 1,200 deselects all presets, typing 1,125 selects 50%', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 2250.0));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;

      // Manual edit to 1,200 (non-preset)
      await tester.enterText(textFieldFinder, '1200');
      await tester.pumpAndSettle();
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '1200');

      // Manual edit to 1,125 (matches 50%)
      await tester.enterText(textFieldFinder, '1125');
      await tester.pumpAndSettle();
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '1125');

      // Manual edit back to 2,250 (matches 100%)
      await tester.enterText(textFieldFinder, '2250');
      await tester.pumpAndSettle();
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '2250');
    });

    testWidgets('7. Balance update: changes available balance dynamically', (tester) async {
      double currentBalance = 2250.0;
      StateSetter? parentSetState;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TransactionsProvider>(create: (_) => TransactionsProvider()),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (ctx, setState) {
                parentSetState = setState;
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: SettlementRequestSheet(availableBalance: currentBalance),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 50% on 2,250 -> 1,125
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byType(TextField).first) as TextField).controller?.text, '1125');

      // Balance refreshed to 5,000
      parentSetState?.call(() {
        currentBalance = 5000.0;
      });
      await tester.pumpAndSettle();

      // Now tap 50% -> 2,500
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byType(TextField).first) as TextField).controller?.text, '2500');

      // Now tap 100% -> 5,000
      await tester.tap(find.text('كامل الرصيد (100%)'));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byType(TextField).first) as TextField).controller?.text, '5000');
    });

    testWidgets('8. Zero / No balance: presets not interactive and empty initial text', (tester) async {
      await tester.pumpWidget(createTestWidget(availableBalance: 0.0));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      expect((tester.widget(textFieldFinder) as TextField).controller?.text, '');
      expect((tester.widget(textFieldFinder) as TextField).enabled, isFalse);
      expect(find.text('كامل الرصيد (100%)'), findsNothing);
    });

    testWidgets('9 & 10. Dark Mode and Light Mode render properly with no render errors', (tester) async {
      // Light Mode
      await tester.pumpWidget(createTestWidget(availableBalance: 3000.0, theme: ThemeData.light()));
      await tester.pumpAndSettle();
      expect(find.text('كامل الرصيد (100%)'), findsOneWidget);

      // Dark Mode
      await tester.pumpWidget(createTestWidget(availableBalance: 3000.0, theme: ThemeData.dark()));
      await tester.pumpAndSettle();
      expect(find.text('كامل الرصيد (100%)'), findsOneWidget);
    });
  });
}
