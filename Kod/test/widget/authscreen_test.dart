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

  testWidgets('Register lozinka kraca od 8 znakova prikazuje gresku', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');
    await tester.enterText(find.byType(TextFormField).at(2), 'ivan@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'Pas1');
    await tester.enterText(find.byType(TextFormField).at(4), 'Pas1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(find.text('Lozinka mora imati barem 8 znakova'), findsOneWidget);
  });

  testWidgets('Register lozinka bez velikog slova prikazuje gresku', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');
    await tester.enterText(find.byType(TextFormField).at(2), 'ivan@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'password1');
    await tester.enterText(find.byType(TextFormField).at(4), 'password1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(
      find.text('Lozinka mora sadržavati barem jedno veliko slovo'),
      findsOneWidget,
    );
  });

  testWidgets('Register lozinka bez malog slova prikazuje gresku', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');
    await tester.enterText(find.byType(TextFormField).at(2), 'ivan@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'PASSWORD1');
    await tester.enterText(find.byType(TextFormField).at(4), 'PASSWORD1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(
      find.text('Lozinka mora sadržavati barem jedno malo slovo'),
      findsOneWidget,
    );
  });

  testWidgets('Register lozinka bez broja prikazuje gresku', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Ivan');
    await tester.enterText(find.byType(TextFormField).at(1), 'Ivic');
    await tester.enterText(find.byType(TextFormField).at(2), 'ivan@test.com');
    await tester.enterText(find.byType(TextFormField).at(3), 'Password');
    await tester.enterText(find.byType(TextFormField).at(4), 'Password');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    expect(
      find.text('Lozinka mora sadržavati barem jedan broj'),
      findsOneWidget,
    );
  });

  testWidgets('Login prazan email prikazuje "obavezno polje"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Email prazan, lozinka popunjena.
    await tester.enterText(find.byType(TextFormField).at(1), 'nekaLozinka1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Email je obavezno polje'), findsOneWidget);
  });

  testWidgets('Login prazna lozinka prikazuje "obavezno polje"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ivan@test.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Lozinka je obavezno polje'), findsOneWidget);
  });

  testWidgets('Toggle vidljivosti lozinke mijenja obscureText na Login formi', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Lozinka polje je drugi TextFormField na Login tabu.
    TextField textFieldWidget() => tester
        .widget<TextField>(find.descendant(
          of: find.byType(TextFormField).at(1),
          matching: find.byType(TextField),
        ));

    expect(textFieldWidget().obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(textFieldWidget().obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    expect(textFieldWidget().obscureText, isTrue);
  });

  testWidgets('Prebacivanje Login -> Register -> Login zadrzava uneseni email u Login formi', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'ivan@test.com');

    // Prebaci se na Register tab.
    await tester.tap(find.text('Register').first);
    await tester.pumpAndSettle();

    expect(find.text('Ime'), findsOneWidget);

    // Vrati se na Login tab.
    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle();

    // TabBarView cuva state widgeta (AutomaticKeepAlive/IndexedStack ponasanje),
    // pa uneseni tekst u Login formi ostaje.
    expect(find.text('ivan@test.com'), findsOneWidget);
  });
}
