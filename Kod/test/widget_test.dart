import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projekt_prvaverzija/main.dart';
import 'package:projekt_prvaverzija/authscreen.dart';

void main() {
  testWidgets('AuthGate prikaze AuthScreen kada korisnik nije prijavljen', (tester) async {
    SharedPreferences.setMockInitialValues({'isLoggedIn': false});

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthGate(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MyHomePage), findsNothing);
  });

  testWidgets('AuthGate prikaze MyHomePage kada je korisnik prijavljen', (tester) async {
    SharedPreferences.setMockInitialValues({'isLoggedIn': true});

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthGate(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MyHomePage), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });
}
