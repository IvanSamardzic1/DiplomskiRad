import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';

typedef SqlConnectFn = Future<void> Function({
  required String connectionId,
  required String host,
  required int port,
  required String database,
  required String username,
  required String password,
});

typedef SqlReadFn = Future<List<Map<String, Object?>>> Function(String connectionId, String sql);
typedef SqlWriteFn = Future<void> Function(String connectionId, String sql);

class SqlConnectionService {
  SqlConnectionService._();
  static final SqlConnectionService instance = SqlConnectionService._();

  static SqlConnectFn _connectFn = SqlConn.connect;
  static SqlReadFn _readFn = SqlConn.read;
  static SqlWriteFn _writeFn = SqlConn.write;

  bool _isConnected = false;
  Future<void>? _connectingFuture;

  static const String _connectionId = 'my_connection';
  static const String _ip = '10.0.2.2'; // emulator -> localhost PC-a
  static const int _port = 1433;
  static const String _dbName = 'diplomski';
  static const String _username = 'Ivan';
  static const String _password = 'ivan1234';

  Future<void> connect() async {
    if (_isConnected) return;
    if (_connectingFuture != null) return _connectingFuture!;

    _connectingFuture = _doConnect();
    try {
      await _connectingFuture;
    } finally {
      _connectingFuture = null;
    }
  }

  Future<void> _doConnect() async {
    await _connectFn(
      connectionId: _connectionId,
      host: _ip,
      port: _port,
      database: _dbName,
      username: _username,
      password: _password,
    );
    _isConnected = true;
    print(("Spojeno na SQL Server s podatcima: $_ip:$_port, DB: $_dbName, User: $_username"));
  }

  Future<void> ensureConnected() async {
    if (!_isConnected) {
      await connect();
    }
  }

  Future<List<Map<String, Object?>>> query(String sql) async {
    await ensureConnected();
    return _readFn(_connectionId, sql);
  }

  Future<void> execute(String sql) async {
    await ensureConnected();
    await _writeFn(_connectionId, sql);
  }

  static void setSqlConnHandlersForTesting({
    required SqlConnectFn connect,
    required SqlReadFn read,
    required SqlWriteFn write,
  }) {
    _connectFn = connect;
    _readFn = read;
    _writeFn = write;
  }

  static void resetSqlConnHandlersForTesting() {
    _connectFn = SqlConn.connect;
    _readFn = SqlConn.read;
    _writeFn = SqlConn.write;
  }

  void resetStateForTesting() {
    _isConnected = false;
    _connectingFuture = null;
  }
}
