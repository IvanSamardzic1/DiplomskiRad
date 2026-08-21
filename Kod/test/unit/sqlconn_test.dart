import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:projekt_prvaverzija/sql_connection.dart';

class _FakeSqlConn {
  int connectCalls = 0;
  int readCalls = 0;
  int writeCalls = 0;

  final List<String> readSql = <String>[];
  final List<String> writeSql = <String>[];

  List<Map<String, Object?>> nextReadResult = <Map<String, Object?>>[];
  Object? connectError;
  Object? readError;
  Object? writeError;

  final Completer<void> connectCompleter = Completer<void>();
  bool useDelayedConnect = false;

  Future<void> connect({
    required String connectionId,
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    connectCalls++;
    if (connectError != null) throw connectError!;
    if (useDelayedConnect) {
      await connectCompleter.future;
    }
  }

  Future<List<Map<String, Object?>>> read(String connectionId, String sql) async {
    readCalls++;
    readSql.add(sql);
    if (readError != null) throw readError!;
    return nextReadResult;
  }

  Future<void> write(String connectionId, String sql) async {
    writeCalls++;
    writeSql.add(sql);
    if (writeError != null) throw writeError!;
  }
}

void main() {
  final service = SqlConnectionService.instance;

  late _FakeSqlConn fake;

  setUp(() {
    fake = _FakeSqlConn();
    service.resetStateForTesting();
    SqlConnectionService.setSqlConnHandlersForTesting(
      connect: fake.connect,
      read: fake.read,
      write: fake.write,
    );
  });

  tearDown(() {
    SqlConnectionService.resetSqlConnHandlersForTesting();
    service.resetStateForTesting();
  });

  test('connect uspostavlja konekciju i ponovni poziv ne spaja opet', () async {
    await service.connect();
    await service.connect();

    expect(fake.connectCalls, 1);
  });

  test('concurrent connect pozivi dijele isti in-flight future', () async {
    fake.useDelayedConnect = true;

    final f1 = service.connect();
    final f2 = service.connect();

    // Dok je prvi connect u tijeku, drugi ne smije otvoriti novu konekciju.
    expect(fake.connectCalls, 1);

    fake.connectCompleter.complete();
    await Future.wait(<Future<void>>[f1, f2]);

    expect(fake.connectCalls, 1);
  });

  test('connect error propagira i omogucuje retry', () async {
    fake.connectError = Exception('connect fail');

    await expectLater(service.connect(), throwsException);
    expect(fake.connectCalls, 1);

    fake.connectError = null;
    await service.connect();
    expect(fake.connectCalls, 2);
  });

  test('query osigurava konekciju i vraca read rezultat', () async {
    fake.nextReadResult = <Map<String, Object?>>[
      <String, Object?>{'id': 1, 'name': 'test'}
    ];

    final rows = await service.query('SELECT 1');

    expect(fake.connectCalls, 1);
    expect(fake.readCalls, 1);
    expect(fake.readSql.single, 'SELECT 1');
    expect(rows, hasLength(1));
    expect(rows.first['id'], 1);
  });

  test('query propagira gresku iz read', () async {
    fake.readError = Exception('read fail');

    await expectLater(service.query('SELECT boom'), throwsException);
    expect(fake.connectCalls, 1);
    expect(fake.readCalls, 1);
  });

  test('execute osigurava konekciju i poziva write', () async {
    await service.execute('UPDATE X SET y=1');

    expect(fake.connectCalls, 1);
    expect(fake.writeCalls, 1);
    expect(fake.writeSql.single, 'UPDATE X SET y=1');
  });

  test('execute propagira gresku iz write', () async {
    fake.writeError = Exception('write fail');

    await expectLater(service.execute('DELETE FROM X'), throwsException);
    expect(fake.connectCalls, 1);
    expect(fake.writeCalls, 1);
  });
}

