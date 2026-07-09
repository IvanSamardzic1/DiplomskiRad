import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ProfilePage prikazuje osnovne widgete profila', (tester) async {
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilePage(),
      ),
    );

    // Pricekaj da initState + _loadUserData zavrse
    await tester.pumpAndSettle();

    expect(find.text('Profil korisnika'), findsOneWidget);
    expect(find.text('Ime'), findsOneWidget);
    expect(find.text('Prezime'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Odjava'), findsOneWidget);
    expect(find.text('Obriši korisnika'), findsOneWidget);
  });

  testWidgets('ProfilePage otvara i zatvara popup za brisanje korisnika', (tester) async {
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilePage(),
      ),
    );

    await tester.pumpAndSettle();

    final deleteTextFinder = find.text('Obriši korisnika');
    expect(deleteTextFinder, findsOneWidget);

    // Za slučaj manjeg ekrana, skrolaj do gumba
    await tester.ensureVisible(deleteTextFinder);
    await tester.tap(deleteTextFinder);
    await tester.pumpAndSettle();

    expect(find.text('Brisanje računa'), findsOneWidget);
    expect(
      find.text('Jeste li sigurni da želite obrisati korisnički račun?'),
      findsOneWidget,
    );
    expect(find.text('Odustani'), findsOneWidget);
    expect(find.text('Obriši'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Odustani'));
    await tester.pumpAndSettle();

    expect(find.text('Brisanje računa'), findsNothing);
  });
}

