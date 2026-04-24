import 'dart:convert';
import 'package:sql_conn/sql_conn.dart';

class SqlConnectionService {
  SqlConnectionService._();
  static final SqlConnectionService instance = SqlConnectionService._();

  bool _isConnected = false;
  Future<void>? _connectingFuture;

  // Stavi svoje podatke ovdje (ili bolje: ucitaj iz configa)
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
    await _connectingFuture;
    _connectingFuture = null;
  }

  Future<void> _doConnect() async {
    await SqlConn.connect(
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
    return SqlConn.read(_connectionId, sql);
  }

  Future<void> execute(String sql) async {
    await ensureConnected();
    await SqlConn.write(_connectionId, sql);
  }
}
