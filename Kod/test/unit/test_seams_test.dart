import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:projekt_prvaverzija/test_seams.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DbAppRepository forwarding', () {
    late List<String> queriedSql;

    setUp(() {
      queriedSql = <String>[];

      DbQueries.setSqlExecutorsForTesting(
        query: (sql) async {
          queriedSql.add(sql);

          if (sql.contains('SELECT TOP 1 idKorisnik')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idKorisnik': 7},
            ];
          }

          if (sql.contains('FROM Recept r')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idRecept': 1, 'naziv': 'Juha', 'autorIme': 'Test Autor'},
            ];
          }

          if (sql.contains('AS hasMissing')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idRecept': 1, 'hasMissing': 1},
              <String, Object?>{'idRecept': 2, 'hasMissing': 0},
            ];
          }

          if (sql.contains('FROM StavkaPopisaTrgovina st')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idStavkaPopisa': 9, 'idKorisnik': 7, 'sastojakIme': 'Mlijeko'},
            ];
          }

          if (sql.contains('FROM Zaliha z')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idZaliha': 11, 'idKorisnik': 7, 'kolicina': 3},
            ];
          }

          if (sql.contains('FROM VrstaObroka')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idVrstaObroka': 1, 'ime': 'dorucak'},
            ];
          }

          if (sql.contains('FROM PlanObroka p')) {
            return <Map<String, Object?>>[
              <String, Object?>{'idPlanObroka': 4, 'idKorisnik': 7, 'tipObroka': 1},
            ];
          }

          return <Map<String, Object?>>[];
        },
        execute: (sql) async {},
      );
    });

    tearDown(() {
      DbQueries.resetSqlExecutorsForTesting();
    });

    test('all repository methods forward to DbQueries and map results', () async {
      const repo = DbAppRepository();

      final userId = await repo.getUserIdByMail('test@test.com');
      expect(userId, 7);

      final recepti = await repo.getReceptiList();
      expect(recepti, hasLength(1));
      expect(recepti.first['naziv'], 'Juha');

      final missing = await repo.getReceptMissingStatusForUser(7);
      expect(missing[1], isTrue);
      expect(missing[2], isFalse);

      final stavke = await repo.getStavkePopisaTrgovineForUser(7);
      expect(stavke, hasLength(1));
      expect(stavke.first['idStavkaPopisa'], 9);

      final zalihe = await repo.getZaliheForUser(7);
      expect(zalihe, hasLength(1));
      expect(zalihe.first['idZaliha'], 11);

      final vrste = await repo.getVrsteObroka();
      expect(vrste, hasLength(1));
      expect(vrste.first['ime'], 'dorucak');

      final plan = await repo.getPlanObrokaZaPeriod(
        idKorisnik: 7,
        od: DateTime(2026, 8, 1),
        doDatuma: DateTime(2026, 8, 7),
      );
      expect(plan, hasLength(1));
      expect(plan.first['idPlanObroka'], 4);

      expect(queriedSql.length, greaterThanOrEqualTo(7));
    });
  });

  group('SharedPrefsSessionStore', () {
    const store = SharedPrefsSessionStore();

    test('returns loggedInEmail with trim+lowercase', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'loggedInEmail': '  USER@Test.com  '},
      );

      final email = await store.getLoggedInEmail();
      expect(email, 'user@test.com');
    });

    test('falls back to email when loggedInEmail missing', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'email': 'Second@Test.com'},
      );

      final email = await store.getLoggedInEmail();
      expect(email, 'second@test.com');
    });

    test('falls back to userEmail and returns null when all are missing', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'userEmail': 'third@Test.com'},
      );
      final fromUserEmail = await store.getLoggedInEmail();
      expect(fromUserEmail, 'third@test.com');

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final none = await store.getLoggedInEmail();
      expect(none, isNull);
    });
  });
}

