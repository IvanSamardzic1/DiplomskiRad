import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/recepti.dart';

void main() {
  testWidgets('ReceptiPage prikazuje loading na prvom frame-u', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: ReceptiPage()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
