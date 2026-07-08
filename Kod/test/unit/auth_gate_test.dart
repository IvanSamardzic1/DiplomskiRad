import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projekt_prvaverzija/main.dart';
import 'package:projekt_prvaverzija/authscreen.dart';

void main() {
  // group grupira testove povezane s AuthGate widgetom
  group('AuthGate', () {
    // TestWidgets je Flutter-ov način testiranja widgeta,
    testWidgets('prikazuje MyHomePage kada je isLoggedIn=true', (tester) async {
      // postavlja isLoggedIn vrijednost u SharedPreferences na true
      SharedPreferences.setMockInitialValues({'isLoggedIn': true});

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );

      // Prvi frame je FutureBuilder loading, pa pricekaj async dio.
      await tester.pumpAndSettle();
      // prikazuje ono sto se ocekuje, odnosno da ce ako je isLoggedIn true,
      // prikazati MyHomePage widget, a ne AuthScreen
      expect(find.byType(MyHomePage), findsOneWidget);
      expect(find.byType(AuthScreen), findsNothing);
    });

    testWidgets('prikazuje AuthScreen kada je isLoggedIn=false', (tester) async {
      SharedPreferences.setMockInitialValues({'isLoggedIn': false});

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthGate(),
        ),
      );

      await tester.pumpAndSettle();
      // sad suprotni slucaj, ako je isLoggedIn false, prikazat ce AuthScreen, a ne MyHomePage
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
    });
  });
}
