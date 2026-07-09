import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/main.dart';
import 'package:projekt_prvaverzija/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MyHomePage prikazuje bottom navigation stavke', (tester) async {
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'Aplikacija za pracenje namirnica'),
      ),
    );

    await tester.pump();

    expect(find.text('Početna'), findsOneWidget);
    expect(find.text('Moje namirnice'), findsOneWidget);
    expect(find.text('Trgovina'), findsOneWidget);
    expect(find.text('Recepti'), findsOneWidget);
    expect(find.text('Plan prehrane'), findsOneWidget);
  });

  testWidgets('Klik na profil ikonu otvara ProfilePage', (tester) async {
    SharedPreferences.setMockInitialValues({
      // Prazan email => _loadUserData zavrsi bez DB poziva
      'loggedInEmail': '',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'Aplikacija za pracenje namirnica'),
      ),
    );

    await tester.pump();

    await tester.tap(find.byIcon(Icons.person));
    await tester.pump(); // pokrene push rute
    await tester.pump(const Duration(milliseconds: 200)); // render sljedeceg frame-a

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Profil korisnika'), findsOneWidget);
  });
}
