import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/home.dart';

void main() {
  testWidgets('HomePage prikazuje naslov i welcome poruku', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(),
      ),
    );

    expect(find.text('Početna stranica'), findsOneWidget);
    expect(find.textContaining('Dobrodošli u aplikaciju za praćenje namirnica'), findsOneWidget);
  });
}
