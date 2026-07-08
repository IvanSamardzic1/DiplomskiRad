import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/authscreen.dart';

void main() {
  testWidgets('AuthScreen prikazuje Login i Register tabove', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    expect(find.text('Prijava / Registracija'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Register'), findsWidgets);
  });

  testWidgets('Login validacija prikaze gresku za neispravan email', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'neispravno');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Unesite ispravan email'), findsOneWidget);
  });

  testWidgets('Register validacija prikaze gresku kad se lozinke ne podudaraju', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    // Polja: Ime, Prezime, Email, Lozinka, Potvrdi lozinku
    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');
    await tester.enterText(find.byType(TextFormField).at(2), 'ivan@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password1');
    await tester.enterText(find.byType(TextFormField).at(4), 'Password2');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(find.text('Lozinke se ne podudaraju'), findsOneWidget);
  });

  testWidgets('Email mora odgovarati formatu regex-a (Register forma)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Prebaci se na Register tab
    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    // Popuni sva obavezna polja ispravno, osim emaila koji mijenjamo u petlji
    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');       // Ime
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');       // Prezime
    await tester.enterText(find.byType(TextFormField).at(3), 'Password1');  // Lozinka
    await tester.enterText(find.byType(TextFormField).at(4), 'Password1');  // Potvrda

    final invalidEmails = <String>[
      'ivan',
      'ivan@',
      '@mail.com',
      'ivan mail.com',
      'ivan@mail',
      'ivan@@mail.com',
    ];

    for (final email in invalidEmails) {
      await tester.enterText(find.byType(TextFormField).at(2), email); // Email
      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
      await tester.pump();

      expect(
        find.text('Unesite ispravan email'),
        findsOneWidget,
        reason: 'Email "$email" mora pasti regex validaciju',
      );
    }
  });


}
