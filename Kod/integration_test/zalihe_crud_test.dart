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

Finder dropdownsIn(Finder scope) {
  return find.descendant(
    of: scope,
    matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
  );
}

Future<void> openMojeNamirnice(WidgetTester tester) async {
  final tabIcon = find.byIcon(Icons.inventory_2);
  await pumpUntilFound(tester, tabIcon);
  await tester.tap(tabIcon);
  await tester.pumpAndSettle(const Duration(seconds: 2));
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

Future<void> deleteIngredientIfExists(
    WidgetTester tester,
    String ingredientName,
    ) async {
  final ingredientFinder = find.text(ingredientName);
  if (ingredientFinder.evaluate().isEmpty) return;

  final ingredientCard = find.ancestor(
    of: ingredientFinder.first,
    matching: find.byType(Card),
  ).first;

  final deleteBtn = find.descendant(
    of: ingredientCard,
    matching: find.byTooltip('Obriši'),
  );

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

  group('Zalihe CRUD', () {
    testWidgets('Dodavanje, uredivanje i brisanje namirnice', (tester) async {
      // PROMIJENI po svojoj bazi:
      const testEmail = 'ivan.test@gmail.com';
      const testPassword = 'ivanTest1';

      // Mora postojati u tvojoj bazi:
      const kategorijaIme = 'Voće';
      const sastojakIme = 'Banana';

      const novaKolicina = '3';
      const novaMinKolicina = '1';
      const uredenaKolicina = '7';

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await ensureLoggedIn(
        tester,
        email: testEmail,
        password: testPassword,
      );

      await openMojeNamirnice(tester);

      // Ocisti ako postoji namirnica
      await deleteIngredientIfExists(tester, sastojakIme);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final addFab = find.byIcon(Icons.add);
      await pumpUntilFound(tester, addFab);
      await tester.tap(addFab);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final addDialog = find.byType(AlertDialog).last;
      await pumpUntilFound(tester, addDialog);
      await pumpUntilFound(tester, find.text('Dodaj namirnicu u zalihu'));

      // Klik na dropdown widget
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

      final dialogFields = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      expect(dialogFields, findsAtLeastNWidgets(3));

      //
      await tester.enterText(dialogFields.at(0), novaKolicina);
      await tester.enterText(dialogFields.at(1), novaMinKolicina);

      await tester.tap(dialogFields.at(2));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final okBtn = find.text('OK').evaluate().isNotEmpty
          ? find.text('OK')
          : find.text('U redu');

      await pumpUntilFound(tester, okBtn);
      await tester.tap(okBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      final spremiBtn = find.widgetWithText(ElevatedButton, 'Spremi');
      await pumpUntilFound(tester, spremiBtn);
      await tester.tap(spremiBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Provjera dodanog
      await pumpUntilFound(tester, find.text(sastojakIme));
      expect(find.text(sastojakIme), findsWidgets);
      expect(find.textContaining('Količina: $novaKolicina'), findsWidgets);

      // Kolicina
      final ingredientCard = find.ancestor(
        of: find.text(sastojakIme).first,
        matching: find.byType(Card),
      ).first;

      final editBtn = find.descendant(
        of: ingredientCard,
        matching: find.byTooltip('Uredi'),
      );

      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.textContaining('Uredi zalihu:'));

      final editDialog = find.byType(AlertDialog).last;
      final editFields = find.descendant(
        of: editDialog,
        matching: find.byType(TextFormField),
      );
      expect(editFields, findsAtLeastNWidgets(3));

      await tester.enterText(editFields.at(0), '');
      await tester.enterText(editFields.at(0), uredenaKolicina);

      final spremiEdit = find.widgetWithText(ElevatedButton, 'Spremi');
      await pumpUntilFound(tester, spremiEdit);
      await tester.tap(spremiEdit);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Količina: $uredenaKolicina'), findsWidgets);

      // 3) Brisanje
      final updatedCard = find.ancestor(
        of: find.text(sastojakIme).first,
        matching: find.byType(Card),
      ).first;

      final deleteBtn = find.descendant(
        of: updatedCard,
        matching: find.byTooltip('Obriši'),
      );

      await tester.ensureVisible(deleteBtn);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await pumpUntilFound(tester, find.text('Potvrda brisanja'));

      final potvrdiBrisanje = find.widgetWithText(ElevatedButton, 'Obriši');
      await tester.tap(potvrdiBrisanje);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(sastojakIme), findsNothing);
    });
  });
}
