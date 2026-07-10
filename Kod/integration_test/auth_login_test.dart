import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projekt_prvaverzija/main.dart' as app;

Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
      Duration timeout = const Duration(seconds: 12),
      Duration step = const Duration(milliseconds: 200),
    }) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Widget nije pronađen unutar timeouta: $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth flow', () {
    testWidgets('TEstiranje logina', (tester) async {
      const testEmail = 'ivan.test@gmail.com';
      const testPassword = 'ivanTest1';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final authTitle = find.text('Prijava / Registracija');
      final homeTitle = find.text('Aplikacija za pracenje namirnica');

      // Prvo odjava ako je korisnik vec prijavljen
      if (homeTitle.evaluate().isNotEmpty) {
        final profileIcon = find.byIcon(Icons.person);
        await pumpUntilFound(tester, profileIcon);
        await tester.tap(profileIcon);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final odjavaBtn = find.text('Odjava');
        await pumpUntilFound(tester, odjavaBtn);
        await tester.tap(odjavaBtn);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      await pumpUntilFound(tester, authTitle);

      final loginFields = find.byType(TextFormField);
      expect(loginFields, findsAtLeastNWidgets(2));

      await tester.enterText(loginFields.at(0), testEmail);
      await tester.enterText(loginFields.at(1), testPassword);

      final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
      await pumpUntilFound(tester, loginBtn);
      await tester.tap(loginBtn);

      //
      try {
        await tester.pumpAndSettle(const Duration(seconds: 6));
      } catch (_) {
        await tester.pump(const Duration(seconds: 1));
      }

      await pumpUntilFound(tester, homeTitle);
      expect(homeTitle, findsOneWidget);

      // Odjava kako bi se vratili u pocetno stanje
      final profileIcon = find.byIcon(Icons.person);
      await pumpUntilFound(tester, profileIcon);
      await tester.tap(profileIcon);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final odjavaBtn = find.text('Odjava');
      await pumpUntilFound(tester, odjavaBtn);
      await tester.tap(odjavaBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await pumpUntilFound(tester, authTitle);
      expect(authTitle, findsOneWidget);
    });
  });
}
