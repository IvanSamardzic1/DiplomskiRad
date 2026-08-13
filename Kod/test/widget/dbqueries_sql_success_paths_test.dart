import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';

class _SqlHarness {
  final List<String> querySql = <String>[];
  final List<String> executeSql = <String>[];
  final List<List<Map<String, Object?>>> queuedQueryResults =
  <List<Map<String, Object?>>>[];

  Future<List<Map<String, Object?>>> query(String sql) async {
    querySql.add(sql);
    if (queuedQueryResults.isEmpty) return <Map<String, Object?>>[];
    return queuedQueryResults.removeAt(0);
  }

  Future<void> execute(String sql) async {
    executeSql.add(sql);
  }

  void queueRows(List<Map<String, Object?>> rows) {
    queuedQueryResults.add(rows);
  }
}

void main() {
  group('DbQueries SQL success paths', () {
    late _SqlHarness sql;

    setUp(() {
      sql = _SqlHarness();
      DbQueries.setSqlExecutorsForTesting(
        query: sql.query,
        execute: sql.execute,
      );
    });

    tearDown(() {
      DbQueries.resetSqlExecutorsForTesting();
    });

    test('getUserByMail returns null when no rows', () async {
      sql.queueRows(<Map<String, Object?>>[]);

      final user = await DbQueries.getUserByMail('  TEST@MAIL.COM  ');

      expect(user, isNull);
      expect(sql.querySql.single, contains("WHERE LOWER(email) = 'test@mail.com'"));
    });

    test('getUserByMail maps fields and defaults empty strings', () async {
      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{
          'email': 'x@y.com',
          'lozinkaHash': 'abc',
          'ime': null,
          'prezime': 'Ivic',
        }
      ]);

      final user = await DbQueries.getUserByMail('x@y.com');

      expect(user, isNotNull);
      expect(user!['email'], 'x@y.com');
      expect(user['lozinkaHash'], 'abc');
      expect(user['ime'], '');
      expect(user['prezime'], 'Ivic');
    });

    test('emailExists true/false', () async {
      sql.queueRows(<Map<String, Object?>>[]);
      final noUser = await DbQueries.emailExists('a@b.com');
      expect(noUser, isFalse);

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'email': 'a@b.com', 'lozinkaHash': '', 'ime': '', 'prezime': ''}
      ]);
      final hasUser = await DbQueries.emailExists('a@b.com');
      expect(hasUser, isTrue);
    });

    test('checkUserCredentials true for matching hash', () async {
      final hash = DbQueries.hashPassword('tajna');
      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{
          'email': 'u@u.com',
          'lozinkaHash': hash,
          'ime': 'U',
          'prezime': 'P',
        }
      ]);

      final ok = await DbQueries.checkUserCredentials('u@u.com', 'tajna');
      expect(ok, isTrue);
    });

    test('checkUserCredentials false for missing user', () async {
      sql.queueRows(<Map<String, Object?>>[]);

      final ok = await DbQueries.checkUserCredentials('u@u.com', 'tajna');
      expect(ok, isFalse);
    });

    test('insertUser executes SQL with normalized email and hash', () async {
      await DbQueries.insertUser(
        ime: "Ivo",
        prezime: "Ivic",
        mail: "  USER@MAIL.COM ",
        plainPassword: "pass123",
      );

      expect(sql.executeSql.length, 1);
      final stmt = sql.executeSql.single;
      expect(stmt, contains("VALUES ('user@mail.com'"));
      expect(stmt, contains(DbQueries.hashPassword('pass123')));
    });

    test('deleteUserByMail and changePassword execute expected SQL', () async {
      await DbQueries.deleteUserByMail(' USER@MAIL.COM ');
      await DbQueries.changePassword(mail: ' USER@MAIL.COM ', newPlainPassword: 'newpass');

      expect(sql.executeSql.length, 2);
      expect(sql.executeSql[0], contains("WHERE LOWER(CAST(email AS NVARCHAR(255))) = 'user@mail.com'"));
      expect(sql.executeSql[1], contains("WHERE LOWER(email) = 'user@mail.com'"));
      expect(sql.executeSql[1], contains(DbQueries.hashPassword('newpass')));
    });

    test('getUserIdByMail parses int and returns null on empty rows', () async {
      sql.queueRows(<Map<String, Object?>>[]);
      final none = await DbQueries.getUserIdByMail('a@b.com');
      expect(none, isNull);

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idKorisnik': '17'}
      ]);
      final id = await DbQueries.getUserIdByMail('a@b.com');
      expect(id, 17);
    });

    test('getZalihaItemForUserSastojak null and row mapping', () async {
      sql.queueRows(<Map<String, Object?>>[]);
      final none = await DbQueries.getZalihaItemForUserSastojak(
        idKorisnik: 1,
        idSastojak: 2,
      );
      expect(none, isNull);

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{
          'idZaliha': 9,
          'idKorisnik': 1,
          'idSastojak': 2,
          'kolicina': 5,
          'datum': '2026-01-01',
          'minKolicina': 1,
        }
      ]);
      final row = await DbQueries.getZalihaItemForUserSastojak(
        idKorisnik: 1,
        idSastojak: 2,
      );
      expect(row, isNotNull);
      expect(row!['idZaliha'], 9);
    });

    test('date SQL format is yyyy-mm-dd in update/upsert/purchase/plan', () async {
      final dt = DateTime(2026, 2, 3, 23, 59, 0);

      await DbQueries.updateZalihaById(
        idZaliha: 1,
        idKorisnik: 2,
        kolicina: 3,
        minKolicina: 0,
        datumRoka: dt,
      );

      await DbQueries.upsertZalihaForUser(
        idKorisnik: 2,
        idSastojak: 4,
        dodatnaKolicina: 3,
        datumRoka: dt,
        minKolicina: 0,
      );

      await DbQueries.purchaseStavkaPopisaTrgovine(
        idKorisnik: 2,
        idStavkaPopisa: 5,
        idSastojak: 4,
        kupljenaKolicina: 2,
        datumRoka: dt,
      );

      await DbQueries.upsertPlanObroka(
        idKorisnik: 2,
        idRecept: 7,
        datumObrok: dt,
        tipObrokaId: 1,
      );

      final all = sql.executeSql.join('\n');
      expect(all, contains('2026-02-03'));
      expect(all, isNot(contains('23:59')));
    });

    test('insert/update/delete stavka popisa execute SQL', () async {
      await DbQueries.insertStavkaPopisaTrgovine(
        idKorisnik: 1,
        idSastojak: 2,
        kolicina: 3,
      );
      await DbQueries.updateStavkaPopisaTrgovineKolicina(
        idStavkaPopisa: 8,
        idKorisnik: 1,
        novaKolicina: 4,
      );
      await DbQueries.deleteStavkaPopisaTrgovineById(
        idStavkaPopisa: 8,
        idKorisnik: 1,
      );

      final joined = sql.executeSql.join('\n');
      expect(joined, contains('INSERT INTO StavkaPopisaTrgovina'));
      expect(joined, contains('UPDATE StavkaPopisaTrgovina'));
      expect(joined, contains('DELETE FROM StavkaPopisaTrgovina'));
    });

    test('insertReceptForAuthor returns new id and throws on empty result', () async {
      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idRecept': '55'}
      ]);

      final id = await DbQueries.insertReceptForAuthor(
        autorKorisnikId: 1,
        naziv: 'Omlet',
        opis: 'Opis',
        vrijemePripremeMin: 10,
        sastojci: const <Map<String, dynamic>>[
          <String, dynamic>{'idSastojak': 1, 'potrebnaKolicina': 2},
        ],
      );
      expect(id, 55);
      expect(sql.querySql.last, contains('INSERT INTO Recept'));

      sql.queueRows(<Map<String, Object?>>[]);
      await expectLater(
        DbQueries.insertReceptForAuthor(
          autorKorisnikId: 1,
          naziv: 'Omlet',
          opis: 'Opis',
          vrijemePripremeMin: 10,
          sastojci: const <Map<String, dynamic>>[
            <String, dynamic>{'idSastojak': 1, 'potrebnaKolicina': 2},
          ],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateReceptByAuthor and deleteReceptByAuthor execute SQL', () async {
      await DbQueries.updateReceptByAuthor(
        idRecept: 10,
        autorKorisnikId: 3,
        naziv: 'Nova verzija',
        opis: 'Opis',
        vrijemePripremeMin: 20,
        sastojci: const <Map<String, dynamic>>[
          <String, dynamic>{'idSastojak': 1, 'potrebnaKolicina': 1},
        ],
      );

      await DbQueries.deleteReceptByAuthor(
        idRecept: 10,
        autorKorisnikId: 3,
      );

      expect(sql.executeSql.length, 2);
      expect(sql.executeSql[0], contains('UPDATE Recept'));
      expect(sql.executeSql[1], contains('DELETE FROM Recept'));
    });

    test('getReceptMissingStatusForUser parses and filters ids', () async {
      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idRecept': '1', 'hasMissing': '1'},
        <String, Object?>{'idRecept': '2', 'hasMissing': '0'},
        <String, Object?>{'idRecept': 'x', 'hasMissing': '1'},
      ]);

      final m = await DbQueries.getReceptMissingStatusForUser(7);

      expect(m.length, 2);
      expect(m[1], isTrue);
      expect(m[2], isFalse);
    });

    test('query list methods map rows', () async {
      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idRecept': 1, 'naziv': 'A'}
      ]);
      final recepti = await DbQueries.getReceptiList();
      expect(recepti.first['naziv'], 'A');

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idVrstaObroka': 1, 'ime': 'dorucak'}
      ]);
      final vrste = await DbQueries.getVrsteObroka();
      expect(vrste.first['ime'], 'dorucak');

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{'idPlanObroka': 1, 'tipObroka': 1}
      ]);
      final plan = await DbQueries.getPlanObrokaZaPeriod(
        idKorisnik: 1,
        od: DateTime(2026, 1, 1),
        doDatuma: DateTime(2026, 1, 3),
      );
      expect(plan.first['idPlanObroka'], 1);
    });

    test('plan mark/delete and ML/heuristic queries execute/map', () async {
      await DbQueries.oznaciObrokKaoNapravljen(
        idPlanObroka: 11,
        idKorisnik: 2,
      );
      await DbQueries.deletePlanObrokaById(
        idPlanObroka: 11,
        idKorisnik: 2,
      );

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{
          'idRecept': 1,
          'tipObroka': 2,
          'vrijemePripremeMin': 15,
          'userOdabranBefore': 1,
          'userIzvrsenBefore': 0,
          'globalnoIzvrsenBefore': 3,
        }
      ]);
      final ml = await DbQueries.getMlFeaturesForUserTip(
        idKorisnik: 2,
        tipObrokaId: 2,
      );
      expect(ml.first['idRecept'], 1);

      sql.queueRows(<Map<String, Object?>>[
        <String, Object?>{
          'idRecept': 5,
          'vrijemePripremeMin': 20,
          'pokrivenostZaliha': 0.7,
          'fifoSignal': 0.4,
          'userOdabranCount': 2,
          'userIzvrsenCount': 1,
        }
      ]);
      final heu = await DbQueries.getHeuristicCandidatesForUser(idKorisnik: 2);
      expect(heu.first['idRecept'], 5);

      final allExec = sql.executeSql.join('\n');
      expect(allExec, contains('UPDATE PlanObroka'));
      expect(allExec, contains('DELETE FROM PlanObroka'));
    });
  });
}

