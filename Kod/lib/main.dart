import 'package:flutter/material.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';
import 'home.dart';
import 'trgovina.dart';
import 'authscreen.dart';
import 'profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sql_connection.dart';
import 'recepti.dart';

// Glavna funkcija aplikacije
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prvo uspostavljamo vezu s SQL Serverom
  try {
    await SqlConnectionService.instance.connect();
    debugPrint('SQL konekcija uspješno uspostavljena.');
  } catch (e) {
    debugPrint('Neuspjelo spajanje na SQL Server: $e');
  }

  runApp(const MyApp()); // Pokretanje aplikacije
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // Postavljamo početni zaslon na AuthGate koji provjerava jel korisnik prijavljen
      home: const AuthGate(),
      routes: {
        // Home ruta koja vodi na početnu stranicu
        '/home': (context) =>
        const MyHomePage(title: 'Aplikacija za praćenje namirnica'),
      },

      // Isključujemo debug banner
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  // klasa  koja provjerava prijavljenost korisnika
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _loadLoginState();
  }
  // dohvaćamo isLoggedIn iz SharedPreferences kako bi provjerili je li korisnik prijavljen
  // ako ga nema, vraća false
  Future<bool> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        // Ako još uvijek čekamo na dohvat podataka, prikazujemo indikator učitavanja
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const MyHomePage(title: 'Aplikacija za praćenje namirnica');
        }

        return const AuthScreen();
      },
    );
  }
}

// Glavna stranica aplikacije koja sadrži navigacijsku traku
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Indeks trenutno odabranog ekrana
  int _selectedIndex = 0;

  // Funkcija za promjenu ekrana, mijenja _selectedIndex i osvježava stanje
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (_selectedIndex) {
      case 0:
        page = HomePage(); // Početna stranica
        break;
      case 1:
        page = const ZalihaNamirnicePage(); // Stranica s zalihama namirnica
        break;
      case 2:
        page = TrgovinaPage(); // Stranica s popisom za trgovinu
        break;
      case 3:
        page = const ReceptiPage(); // Stranica s receptima
        break;
      case 4:
        page = const PlanPrehranePage(); // Stranica s planom obroka
        break;

      default:
        page = HomePage();
    }


    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // Ikona profila koja vodi na stranicu profila korisnika
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      // dodajemo navigacijsku traku na dno ekrana
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // Stavke navigacijske trake, svaka s ikonom i tekstom
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Početna',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Moje namirnice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Trgovina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Recepti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Plan prehrane',
          ),

        ],
        //Postavke navigacijske trake
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 16.0,
        unselectedFontSize: 14.0,
        onTap: _onItemTapped,
      ),
    );
  }
}