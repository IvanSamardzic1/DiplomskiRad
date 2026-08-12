import 'package:shared_preferences/shared_preferences.dart';

import 'dbqueries.dart';

abstract class AppRepository {
  Future<int?> getUserIdByMail(String mail);

  Future<List<Map<String, dynamic>>> getReceptiList();
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik);

  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik);

  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik);

  Future<List<Map<String, dynamic>>> getVrsteObroka();
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  });
}

class DbAppRepository implements AppRepository {
  const DbAppRepository();

  @override
  Future<int?> getUserIdByMail(String mail) => DbQueries.getUserIdByMail(mail);

  @override
  Future<List<Map<String, dynamic>>> getReceptiList() => DbQueries.getReceptiList();

  @override
  Future<Map<int, bool>> getReceptMissingStatusForUser(int idKorisnik) =>
      DbQueries.getReceptMissingStatusForUser(idKorisnik);

  @override
  Future<List<Map<String, dynamic>>> getStavkePopisaTrgovineForUser(int idKorisnik) =>
      DbQueries.getStavkePopisaTrgovineForUser(idKorisnik);

  @override
  Future<List<Map<String, dynamic>>> getZaliheForUser(int idKorisnik) =>
      DbQueries.getZaliheForUser(idKorisnik);

  @override
  Future<List<Map<String, dynamic>>> getVrsteObroka() => DbQueries.getVrsteObroka();

  @override
  Future<List<Map<String, dynamic>>> getPlanObrokaZaPeriod({
    required int idKorisnik,
    required DateTime od,
    required DateTime doDatuma,
  }) =>
      DbQueries.getPlanObrokaZaPeriod(
        idKorisnik: idKorisnik,
        od: od,
        doDatuma: doDatuma,
      );
}

abstract class SessionStore {
  Future<String?> getLoggedInEmail();
}

class SharedPrefsSessionStore implements SessionStore {
  const SharedPrefsSessionStore();

  @override
  Future<String?> getLoggedInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('loggedInEmail') ??
        prefs.getString('email') ??
        prefs.getString('userEmail');
    return email?.trim().toLowerCase();
  }
}
