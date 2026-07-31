import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projekt_prvaverzija/main.dart' as app;

Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
      Duration timeout = const Duration(seconds: 15),
      Duration step = const Duration(milliseconds: 200),
    }) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    // Finderi izgrađeni s `.last`/`.first` bacaju StateError ako trenutno
    // nema nijednog widgeta koji odgovara, pa to tretiramo kao "nije pronađeno"
    try {
      if (finder.evaluate().isNotEmpty) return;
    } catch (_) {
      // ignoriramo i pokušavamo ponovno u sljedecoj iteraciji
    }
  }
  throw TestFailure('Widget nije pronađen unutar timeouta: $finder');
}

Finder dropdownsIn(Finder scope) {
  return find.descendant(
    of: scope,
    matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
  );
}

Future<void> ensureLoggedIn(
    WidgetTester tester, {
      required String email,
      required String password,
    }) async {
  final homeTitle = find.text('Aplikacija za pracenje namirnica');
  final authTitle = find.text('Prijava / Registracija');

  if (homeTitle.evaluate().isNotEmpty) return;

  await pumpUntilFound(tester, authTitle);

  final loginFields = find.byType(TextFormField);
  expect(loginFields, findsAtLeastNWidgets(2));

  await tester.enterText(loginFields.at(0), email);
  await tester.enterText(loginFields.at(1), password);

  final loginBtn = find.widgetWithText(ElevatedButton, 'Login');
  await pumpUntilFound(tester, loginBtn);
  await tester.tap(loginBtn);

  try {
    await tester.pumpAndSettle(const Duration(seconds: 6));
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }

  await pumpUntilFound(tester, homeTitle);
}

Future<void> openRecepti(WidgetTester tester) async {
  final tabIcon = find.byIcon(Icons.menu_book);
  await pumpUntilFound(tester, tabIcon);
  await tester.tap(tabIcon);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

// Brise recept s popisa ako postoji recept s danim nazivom (samo ako je
// trenutni korisnik autor, jer se inace ne prikazuju Uredi/Obrisi ikone)
Future<void> deleteRecipeIfExists(WidgetTester tester, String naziv) async {
  final nazivFinder = find.text(naziv);
  if (nazivFinder.evaluate().isEmpty) return;

  final card = find.ancestor(
    of: nazivFinder.first,
    matching: find.byType(Card),
  ).first;

  final deleteBtn = find.descendant(
    of: card,
    matching: find.byTooltip('Obriši'),
  );
  if (deleteBtn.evaluate().isEmpty) return;

  await tester.ensureVisible(deleteBtn);
  await tester.tap(deleteBtn);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  final confirmBtn = find.widgetWithText(ElevatedButton, 'Obriši');
  await pumpUntilFound(tester, confirmBtn);
  await tester.tap(confirmBtn);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Pokriva dodavanje novog recepta sa sastojkom te njegovo brisanje
  group('Recepti', () {
    testWidgets('Dodavanje novog recepta sa sastojkom', (tester) async {
      const testEmail = 'ivan.test@gmail.com';
      const testPassword = 'ivanTest1';

      const nazivRecepta = 'Integracijski test recept';
      const opisRecepta = 'Recept kreiran u sklopu integracijskog testa.';
      const vrijemePripreme = '15';

      // Mora postojati u bazi (isti sastojak koriste i drugi testovi)
      const sastojakIme = 'Govedina';
      const kolicinaSastojka = '200';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await ensureLoggedIn(tester, email: testEmail, password: testPassword);
      await openRecepti(tester);

      // Ocisti eventualni ostatak iz prethodnog neuspjelog runa
      await deleteRecipeIfExists(tester, nazivRecepta);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 1) Otvaranje dijaloga za dodavanje novog recepta
      final addFab = find.byIcon(Icons.add);
      await pumpUntilFound(tester, addFab);
      await tester.tap(addFab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final addDialog = find.byType(AlertDialog).last;
      await pumpUntilFound(tester, find.text('Novi recept'));

      // Popunjavanje osnovnih podataka o receptu (naziv, vrijeme, opis)
      final baseFields = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      await pumpUntilFound(tester, baseFields);
      expect(baseFields, findsAtLeastNWidgets(3));

      await tester.enterText(baseFields.at(0), nazivRecepta);
      await tester.enterText(baseFields.at(1), vrijemePripreme);
      await tester.enterText(baseFields.at(2), opisRecepta);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 2) Dodavanje sastojka receptu preko dropdowna
      final sastojakDropdown = dropdownsIn(addDialog);
      await pumpUntilFound(tester, sastojakDropdown);
      await tester.ensureVisible(sastojakDropdown.first);
      await tester.tap(sastojakDropdown.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final sastojakOptionFinder = find.textContaining(sastojakIme);

      // Lista sastojaka grupirana i ide na dolje, pa je potrebno listati da bi se nasao
      // zeljeni sastojakk 
      final dropdownScrollable = find.byType(Scrollable).last;
      await tester.dragUntilVisible(
        sastojakOptionFinder,
        dropdownScrollable,
        const Offset(0, -50),
      );
      await pumpUntilFound(tester, sastojakOptionFinder);
      await tester.tap(sastojakOptionFinder.last);
      await tester.pumpAndSettle(const Duration(seconds: 1));


      // Kolicina sastojka je zadnje TextFormField polje u dijalogu nakon odabira
      final fieldsAfterDropdown = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fieldsAfterDropdown.last, kolicinaSastojka);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final dodajSastojakBtn = find.ancestor(
        of: find.text('Dodaj sastojak'),
        matching: find.byWidgetPredicate((w) => w is ElevatedButton),
      );

      await pumpUntilFound(tester, dodajSastojakBtn);
      await tester.tap(dodajSastojakBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Provjera da je sastojak dodan na listu unutar dijaloga
      expect(
        find.descendant(of: addDialog, matching: find.text(sastojakIme)),
        findsOneWidget,
      );

      // Spremanje recepta
      final dodajBtn = find.widgetWithText(ElevatedButton, 'Dodaj');
      await pumpUntilFound(tester, dodajBtn);
      await tester.tap(dodajBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Provjera da je recept prikazan na popisu
      await pumpUntilFound(tester, find.text(nazivRecepta));
      expect(find.text(nazivRecepta), findsOneWidget);

      // Brisanje testnog recepta
      await deleteRecipeIfExists(tester, nazivRecepta);
      expect(find.text(nazivRecepta), findsNothing);
    });
  });
}

