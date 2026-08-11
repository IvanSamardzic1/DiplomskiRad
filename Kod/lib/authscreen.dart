import 'package:flutter/material.dart';
import 'package:projekt_prvaverzija/dbqueries.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerFirstNameController = TextEditingController();
  final _registerLastNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _registerConfirmPasswordVisible = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerFirstNameController.dispose();
    _registerLastNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName je obavezno polje';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator(value, 'Email');
    if (required != null) return required;

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value!.trim())) {
      return 'Unesite ispravan email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final required = _requiredValidator(value, 'Lozinka');
    if (required != null) return required;

    final password = value!;
    if (password.length < 8) {
      return 'Lozinka mora imati barem 8 znakova';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Lozinka mora sadržavati barem jedno veliko slovo';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Lozinka mora sadržavati barem jedno malo slovo';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Lozinka mora sadržavati barem jedan broj';
    }
    return null;
  }


  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          title: const Text(
            'Greška',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.red),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    final mail = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    final exists = await DbQueries.emailExists(mail);
    if (!exists) {
      //_showMessage('Korisnik s tim emailom ne postoji.');
      await _showErrorDialog('Korisnik s tim emailom ne postoji.');
      return;
    }

    final valid = await DbQueries.checkUserCredentials(mail, password);
    if (!valid) {
      //_showMessage('Pogrešna lozinka.');
      await _showErrorDialog('Pogrešna lozinka.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loggedInEmail', mail.toLowerCase());

    if (!mounted) return;
    print("Prijava uspješna za korisnika: $mail");
    Navigator.pushReplacementNamed(context, '/home');

  }

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    if (!_registerFormKey.currentState!.validate()) return;

    final ime = _registerFirstNameController.text.trim();
    final prezime = _registerLastNameController.text.trim();
    final mail = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    final exists = await DbQueries.emailExists(mail);
    if (exists) {
      //_showMessage('Ovaj mail je već registriran.');
      await _showErrorDialog('Ovaj mail je već registriran.');
      print("Ovaj mail je već registriran: $mail");
      return;
    }

    await DbQueries.insertUser(
      ime: ime,
      prezime: prezime,
      mail: mail,
      plainPassword: password,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loggedInEmail', mail.toLowerCase());

    if (!mounted) return;
    print("Registracija uspješna za korisnika: $mail");
    Navigator.pushReplacementNamed(context, '/home');
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Prijava / Registracija'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Login'),
              Tab(text: 'Register'),
            ],
          ),
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
            TabBarView(
              children: [
                _buildLoginTab(),
                _buildRegisterTab(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _loginFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _loginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _loginPasswordController,
                obscureText: !_loginPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Lozinka',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _loginPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _loginPasswordVisible = !_loginPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) => _requiredValidator(value, 'Lozinka'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitLogin,
                  child: const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _registerFormKey,
          child: Column(
            children: [
              TextFormField(
                controller: _registerFirstNameController,
                decoration: const InputDecoration(
                  labelText: 'Ime',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _requiredValidator(value, 'Ime'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registerLastNameController,
                decoration: const InputDecoration(
                  labelText: 'Prezime',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _requiredValidator(value, 'Prezime'),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _registerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: _emailValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registerPasswordController,
                obscureText: !_registerPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Lozinka',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _registerPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _registerPasswordVisible = !_registerPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: _passwordValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _registerConfirmPasswordController,
                obscureText: !_registerConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Potvrdi lozinku',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _registerConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _registerConfirmPasswordVisible =
                        !_registerConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  final required = _requiredValidator(value, 'Potvrda lozinke');
                  if (required != null) return required;
                  if (value != _registerPasswordController.text) {
                    return 'Lozinke se ne podudaraju';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitRegister,
                  child: const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
