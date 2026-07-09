import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ZalihaNamirnicePage prikazuje loading na prvom frame-u', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: ZalihaNamirnicePage()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ZalihaNamirnicePage prikazuje gresku kad nema prijavljenog korisnika', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: ZalihaNamirnicePage()),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Nema prijavljenog korisnika'), findsOneWidget);
    expect(find.text('Pokušaj ponovno'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
