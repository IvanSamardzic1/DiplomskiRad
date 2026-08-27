import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projekt_prvaverzija/main.dart' as app;

// Pomocna funkc koja pumpa widget stablo dok se trazeni finder
// ne pojavi
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

// Osigurava da svaki test krece iz poznatog stanja, a to je odjavljen korisnik
Future<void> logoutIfLoggedIn(WidgetTester tester) async {
  final homeTitle = find.text('Aplikacija za praćenje namirnica');
  if (homeTitle.evaluate().isEmpty) return;

  final profileIcon = find.byIcon(Icons.person);
  await pumpUntilFound(tester, profileIcon);
  await tester.tap(profileIcon);
  await tester.pumpAndSettle(const Duration(seconds: 2));

  final odjavaBtn = find.text('Odjava');
  await pumpUntilFound(tester, odjavaBtn);
  await tester.tap(odjavaBtn);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // end-to-end test novog racuna: registracija, provjera spremanja u bazu, prikaz u profiilu
  // i brisanje. Koristimo jedinstveni email kako ne bi doslo do konflikta
  group('Registracija novog korisnika', () {
    testWidgets('Registracija, prijava i brisanje racuna', (tester) async {
      // Izrada jedinstvenog maila
      final unique = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'integration.test.$unique@gmail.com';
      const testPassword = 'TestLozinka1';
      const testIme = 'Integracijski';
      const testPrezime = 'Test';


      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await logoutIfLoggedIn(tester);

      final authTitle = find.text('Prijava / Registracija');
      await pumpUntilFound(tester, authTitle);

      // Prebacivanje na Register tab
      final registerTab = find.widgetWithText(Tab, 'Register');
      await pumpUntilFound(tester, registerTab);
      await tester.tap(registerTab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final registerFields = find.byType(TextFormField);
      expect(registerFields, findsAtLeastNWidgets(5));

      // Popunjavanje polja za registraciju
      await tester.enterText(registerFields.at(0), testIme);
      await tester.enterText(registerFields.at(1), testPrezime);
      await tester.enterText(registerFields.at(2), testEmail);
      await tester.enterText(registerFields.at(3), testPassword);
      await tester.enterText(registerFields.at(4), testPassword);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final registerBtn = find.widgetWithText(ElevatedButton, 'Register');
      await pumpUntilFound(tester, registerBtn);
      await tester.tap(registerBtn);

      try {
        await tester.pumpAndSettle(const Duration(seconds: 6));
      } catch (_) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Ako se korisnik uspjesno registrirao, trebao bi biti preusmjeren na
      // home screen. Provjeravamo da li je home screen prikazan
      final homeTitle = find.text('Aplikacija za praćenje namirnica');
      await pumpUntilFound(tester, homeTitle);
      expect(homeTitle, findsOneWidget);

      // Provjera da su podaci ispravno spremljeni, trazimo profil
      final profileIcon = find.byIcon(Icons.person);
      await pumpUntilFound(tester, profileIcon);
      await tester.tap(profileIcon);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Cekanje da se profil ucita (spor SQL upit preko mreze emulatora)
      final deleteIcon = find.byIcon(Icons.delete_forever);
      await pumpUntilFound(
        tester,
        deleteIcon,
        timeout: const Duration(seconds: 20),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      // potvrda da je email prikazan na profilu
      expect(find.text(testEmail), findsOneWidget);

      // Ciscenje testnih podataka, da baza ne akumulira testne korisnike
      // nakon svakog pokretanja testa
      await tester.ensureVisible(deleteIcon);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final confirmDeleteBtn = find.widgetWithText(TextButton, 'Obriši');
      await pumpUntilFound(tester, confirmDeleteBtn);
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await pumpUntilFound(tester, authTitle);
      expect(authTitle, findsOneWidget);
    });

    // Testiramo validaciju duplog emaila, odnosno koristi postojeci racun koji se
    // koristi u drugim testovima, pa se ne smije brisati
    testWidgets('Registracija s vec postojecim mailom prikazuje gresku', (tester) async {
      const existingEmail = 'ivan.test@gmail.com';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await logoutIfLoggedIn(tester);

      final authTitle = find.text('Prijava / Registracija');
      await pumpUntilFound(tester, authTitle);

      final registerTab = find.widgetWithText(Tab, 'Register');
      await pumpUntilFound(tester, registerTab);
      await tester.tap(registerTab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final registerFields = find.byType(TextFormField);
      expect(registerFields, findsAtLeastNWidgets(5));

      await tester.enterText(registerFields.at(0), 'Ivan');
      await tester.enterText(registerFields.at(1), 'Test');
      await tester.enterText(registerFields.at(2), existingEmail);
      await tester.enterText(registerFields.at(3), 'TestLozinka1');
      await tester.enterText(registerFields.at(4), 'TestLozinka1');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final registerBtn = find.widgetWithText(ElevatedButton, 'Register');
      await pumpUntilFound(tester, registerBtn);
      await tester.tap(registerBtn);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final errorText = find.text('Ovaj mail je već registriran.');
      await pumpUntilFound(tester, errorText);
      // Provjera da je greska prikazana
      expect(errorText, findsOneWidget);

      final okBtn = find.widgetWithText(TextButton, 'OK');
      await tester.tap(okBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}
