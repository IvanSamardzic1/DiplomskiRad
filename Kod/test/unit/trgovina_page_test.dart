import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/trgovina.dart';

void main() {
  testWidgets('TrgovinaPage prikazuje loading na prvom frame-u', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: TrgovinaPage()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('TrgovinaPage prikazuje gresku ako nema prijavljenog korisnika', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: TrgovinaPage()),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
  });
}
