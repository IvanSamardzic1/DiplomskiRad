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
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Widget nije pronađen unutar timeouta: $finder');
}

// Pomocna funkcija za pronalazenje DropdownButttonFormField widgeta
// Jer stranica moze imati vise dropdowna istog tipa istovremeno
Finder dropdownsIn(Finder scope) {
  return find.descendant(
    of: scope,
    matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
  );
}

// preskace login ako je korisnik  vec prijavljen
Future<void> ensureLoggedIn(
    WidgetTester tester, {
      required String email,
      required String password,
    }) async {
  final homeTitle = find.text('Aplikacija za praćenje namirnica');
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

Future<void> openTrgovina(WidgetTester tester) async {
  final tabIcon = find.byIcon(Icons.store);
  await pumpUntilFound(tester, tabIcon);
  await tester.tap(tabIcon);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

// Uklanja stavku s popisa za trgovinu ako postoji ranije
Future<void> deleteShoppingItemIfExists(
    WidgetTester tester,
    String ingredientName,
    ) async {
  final ingredientFinder = find.text(ingredientName);
  if (ingredientFinder.evaluate().isEmpty) return;

  final card = find.ancestor(
    of: ingredientFinder.first,
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

  final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Obriši');
  await pumpUntilFound(tester, confirmDeleteBtn);
  await tester.tap(confirmDeleteBtn);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Pokriva glavni tok - CRUD operacije na popisu za trgovinu i
  // oznacavanje stavke kao kupljene (koja uklanja stavku s popisa)
  group('Trgovina - popis za kupovinu', () {
    testWidgets('Dodavanje, uredivanje kolicine i oznacavanje kao kupljeno', (tester) async {
      const testEmail = 'ivan.test@gmail.com';
      const testPassword = 'ivanTest1';

      // Mora postojati u bazi (isti podaci kao u zalihe_crud_test.dart)
      const kategorijaIme = 'Voće';
      const sastojakIme = 'Banana';

      const pocetnaKolicina = '2';
      const uredenaKolicina = '5';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await ensureLoggedIn(tester, email: testEmail, password: testPassword);
      await openTrgovina(tester);

      // Ocisti ako vec postoji stavka od prethodnog neuspjelog runa
      await deleteShoppingItemIfExists(tester, sastojakIme);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // OTvara dijalog za dodavanje nove stavke, bira kategoriju pa sastojak

      // 1) Dodavanje nove stavke na popis
      final addFab = find.widgetWithIcon(FloatingActionButton, Icons.add);
      await pumpUntilFound(tester, addFab);
      await tester.tap(addFab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final addDialog = find.byType(AlertDialog).last;
      await pumpUntilFound(tester, addDialog);
      await pumpUntilFound(tester, find.text('Dodaj na popis za trgovinu'));

      final ddsBefore = dropdownsIn(addDialog);
      await pumpUntilFound(tester, ddsBefore);
      final kategorijaDropdown = ddsBefore.first;

      await tester.ensureVisible(kategorijaDropdown);
      await tester.tap(kategorijaDropdown);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final kategorijaOption = find.text(kategorijaIme).last;
      await pumpUntilFound(tester, kategorijaOption);
      await tester.tap(kategorijaOption);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final ddsAfter = dropdownsIn(addDialog);
      await pumpUntilFound(tester, ddsAfter);
      expect(ddsAfter, findsAtLeastNWidgets(2));

      final sastojakDropdown = ddsAfter.last;
      await tester.ensureVisible(sastojakDropdown);
      await tester.tap(sastojakDropdown);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final sastojakOption = find.text(sastojakIme).last;
      await pumpUntilFound(tester, sastojakOption);
      await tester.tap(sastojakOption);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final kolicinaField = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      await pumpUntilFound(tester, kolicinaField);
      await tester.enterText(kolicinaField.last, pocetnaKolicina);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final dodajBtn = find.widgetWithText(ElevatedButton, 'Dodaj');
      await pumpUntilFound(tester, dodajBtn);
      await tester.tap(dodajBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Provjera da je stavka dodana s ispravnom kolicinom
      await pumpUntilFound(tester, find.text(sastojakIme));
      expect(find.text(sastojakIme), findsWidgets);
      expect(find.textContaining('Potrebno: $pocetnaKolicina'), findsWidgets);

      // 2) Uredivanje kolicine postojece stavke
      final card = find.ancestor(
        of: find.text(sastojakIme).first,
        matching: find.byType(Card),
      ).first;

      final editBtn = find.descendant(
        of: card,
        matching: find.byTooltip('Uredi'),
      );
      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text('Uredi količinu'));
      final editField = find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.byType(TextField),
      );
      await tester.enterText(editField, '');
      await tester.enterText(editField, uredenaKolicina);

      final spremiEdit = find.widgetWithText(ElevatedButton, 'Spremi');
      await pumpUntilFound(tester, spremiEdit);
      await tester.tap(spremiEdit);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Potrebno: $uredenaKolicina'), findsWidgets);

      // 3) Oznacavanje kao kupljeno, stavka se uklanja s popisa
      final purchaseBtn = find.descendant(
        of: find.ancestor(
          of: find.text(sastojakIme).first,
          matching: find.byType(Card),
        ).first,
        matching: find.byTooltip('Označi kao kupljeno'),
      );
      await tester.ensureVisible(purchaseBtn);
      await tester.tap(purchaseBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text('Potvrda kupnje'));
      final spremiKupnju = find.widgetWithText(ElevatedButton, 'Spremi');
      await pumpUntilFound(tester, spremiKupnju);
      await tester.tap(spremiKupnju);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(sastojakIme), findsNothing);
    });

    // Jednostavni scenarij koji testira direktno brisanje stavke neovisno o kupnji

    testWidgets('Brisanje stavke s popisa za trgovinu', (tester) async {
      const testEmail = 'ivan.test@gmail.com';
      const testPassword = 'ivanTest1';

      const kategorijaIme = 'Voće';
      const sastojakIme = 'Banana';
      const kolicina = '1';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await ensureLoggedIn(tester, email: testEmail, password: testPassword);
      await openTrgovina(tester);

      await deleteShoppingItemIfExists(tester, sastojakIme);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Dodaj stavku koju cemo odmah obrisati
      final addFab = find.widgetWithIcon(FloatingActionButton, Icons.add);
      await pumpUntilFound(tester, addFab);
      await tester.tap(addFab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final addDialog = find.byType(AlertDialog).last;
      await pumpUntilFound(tester, find.text('Dodaj na popis za trgovinu'));

      final ddsBefore = dropdownsIn(addDialog);
      await pumpUntilFound(tester, ddsBefore);
      await tester.ensureVisible(ddsBefore.first);
      await tester.tap(ddsBefore.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text(kategorijaIme).last);
      await tester.tap(find.text(kategorijaIme).last);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final ddsAfter = dropdownsIn(addDialog);
      await pumpUntilFound(tester, ddsAfter);
      final sastojakDropdown = ddsAfter.last;
      await tester.ensureVisible(sastojakDropdown);
      await tester.tap(sastojakDropdown);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text(sastojakIme).last);
      await tester.tap(find.text(sastojakIme).last);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final kolicinaField = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(kolicinaField.last, kolicina);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final dodajBtn = find.widgetWithText(ElevatedButton, 'Dodaj');
      await pumpUntilFound(tester, dodajBtn);
      await tester.tap(dodajBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await pumpUntilFound(tester, find.text(sastojakIme));

      // Brisanje
      final card = find.ancestor(
        of: find.text(sastojakIme).first,
        matching: find.byType(Card),
      ).first;

      final deleteBtn = find.descendant(
        of: card,
        matching: find.byTooltip('Obriši'),
      );
      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text('Potvrda brisanja'));
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Obriši');
      await pumpUntilFound(tester, confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(sastojakIme), findsNothing);
    });
  });
}
