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

  testWidgets('Klik na Odjava navigira natrag na pocetnu rutu (/)', (tester) async {
    // Prazan loggedInEmail izbjegava poziv na DbQueries.getUserByMail (DB poziv).
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
      'isLoggedIn': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/profile',
        routes: {
          '/': (context) => const Scaffold(body: Text('Pocetna ruta')),
          '/profile': (context) => const ProfilePage(),
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Profil korisnika'), findsOneWidget);

    final logoutFinder = find.text('Odjava');
    await tester.ensureVisible(logoutFinder);
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();

    expect(find.text('Pocetna ruta'), findsOneWidget);
    expect(find.text('Profil korisnika'), findsNothing);

    // isLoggedIn i loggedInEmail moraju biti ocisceni nakon odjave.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isFalse);
    expect(prefs.getString('loggedInEmail'), isNull);
  });

  testWidgets('Potvrda brisanja racuna (klik na Obrisi) navigira natrag na pocetnu rutu', (tester) async {
    // Prazan loggedInEmail izbjegava poziv na DbQueries.deleteUserByMail (DB poziv).
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
      'isLoggedIn': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/profile',
        routes: {
          '/': (context) => const Scaffold(body: Text('Pocetna ruta')),
          '/profile': (context) => const ProfilePage(),
        },
      ),
    );

    await tester.pumpAndSettle();

    final deleteTextFinder = find.text('Obriši korisnika');
    await tester.ensureVisible(deleteTextFinder);
    await tester.tap(deleteTextFinder);
    await tester.pumpAndSettle();

    expect(find.text('Brisanje računa'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Obriši'));
    await tester.pumpAndSettle();

    expect(find.text('Brisanje računa'), findsNothing);
    expect(find.text('Pocetna ruta'), findsOneWidget);
    expect(find.text('Profil korisnika'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isLoggedIn'), isFalse);
    expect(prefs.getString('loggedInEmail'), isNull);
  });
}

