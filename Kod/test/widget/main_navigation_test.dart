import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/main.dart';
import 'package:projekt_prvaverzija/profile.dart';
import 'package:projekt_prvaverzija/home.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';
import 'package:projekt_prvaverzija/trgovina.dart';
import 'package:projekt_prvaverzija/recepti.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';

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

  testWidgets('Klik na svaku bottom nav stavku mijenja prikazani page widget', (tester) async {
    SharedPreferences.setMockInitialValues({
      'loggedInEmail': '',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MyHomePage(title: 'Aplikacija za pracenje namirnica'),
      ),
    );

    await tester.pump();

    // Pocetno stanje (index 0) - HomePage
    expect(find.byType(HomePage), findsOneWidget);

    // Klik na "Moje namirnice" (index 1) -> ZalihaNamirnicePage
    await tester.tap(find.text('Moje namirnice'));
    await tester.pump();
    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(ZalihaNamirnicePage), findsOneWidget);

    // Klik na "Trgovina" (index 2) -> TrgovinaPage
    await tester.tap(find.text('Trgovina'));
    await tester.pump();
    expect(find.byType(ZalihaNamirnicePage), findsNothing);
    expect(find.byType(TrgovinaPage), findsOneWidget);

    // Klik na "Recepti" (index 3) -> ReceptiPage
    await tester.tap(find.text('Recepti'));
    await tester.pump();
    expect(find.byType(TrgovinaPage), findsNothing);
    expect(find.byType(ReceptiPage), findsOneWidget);

    // Klik na "Plan prehrane" (index 4) -> PlanPrehranePage
    await tester.tap(find.text('Plan prehrane'));
    await tester.pump();
    expect(find.byType(ReceptiPage), findsNothing);
    expect(find.byType(PlanPrehranePage), findsOneWidget);

    // PlanPrehranePage asinkrono provjerava prijavljenog korisnika i, buduci
    // da u ovom testu nema postavljenog "email"/"loggedInEmail"/"userEmail"
    // kljuca, prikazuje modalni AlertDialog s greskom. Taj dijalog blokira
    // dodire na bottom nav ispod sebe, pa ga treba zatvoriti prije nastavka.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(AlertDialog).evaluate().isNotEmpty) break;
    }
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(TextButton, 'OK'));
      await tester.pump();
    }

    // Povratak na "Početna" (index 0) -> HomePage
    await tester.tap(find.text('Početna'));
    await tester.pump();
    expect(find.byType(PlanPrehranePage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
