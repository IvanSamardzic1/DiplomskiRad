import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget _hostedPlanPage() {
    return const MaterialApp(
      home: Scaffold(
        body: PlanPrehranePage(),
      ),
    );
  }

  testWidgets('PlanPrehranePage prikazuje naslov i chipove dana', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_hostedPlanPage());

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Plan prehrane'), findsOneWidget);
    expect(find.text('Plan za sljedeća 3 dana'), findsOneWidget);
    expect(find.textContaining('Danas'), findsOneWidget);
    expect(find.textContaining('Sutra'), findsOneWidget);
    expect(find.textContaining('Prekosutra'), findsOneWidget);
  });

}
