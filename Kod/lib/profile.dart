import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'authscreen.dart';
import 'database_helper2.dart' as auth_db;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  String _ime = '';
  String _prezime = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('loggedInEmail');

    if (email != null && email.trim().isNotEmpty) {
      final user = await auth_db.DatabaseHelper.getUserByMail(email);
      if (user != null) {
        _ime = (user['ime'] ?? '').toString();
        _prezime = (user['prezime'] ?? '').toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('loggedInEmail');

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Profil korisnika'),
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/slike/logo.png',
              fit: BoxFit.fitWidth,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: _ime,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Ime',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _prezime,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Prezime',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

