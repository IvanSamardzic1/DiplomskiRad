import 'package:flutter/material.dart';
import 'package:projekt_prvaverzija/plan_prehrane.dart';
import 'package:projekt_prvaverzija/zaliheKorisnika.dart';
import 'home.dart';
import 'trgovina.dart';
import 'authscreen.dart';
import 'profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sql_connection.dart';
import 'zaliheKorisnika.dart';
import 'recepti.dart';
import 'plan_prehrane.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

      home: const AuthGate(),
      routes: {
        '/home': (context) =>
        const MyHomePage(title: 'Aplikacija za pracenje namirnica'),
      },

      //home: const MyHomePage(title: 'Aplikacija za praćenje namirnica'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

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

  Future<bool> _loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const MyHomePage(title: 'Aplikacija za pracenje namirnica');
        }

        return const AuthScreen();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Indeks trenutno odabranog ekrana
  int _selectedIndex = 0;

  // f+Funkcija za promjenu ekrana
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
        page = const ZalihaNamirnicePage();
        break;
      case 2:
        page = TrgovinaPage(); // Stranica s trgovinom
        break;
      case 3:
        page = const ReceptiPage();
        break;
      case 4:
        page = const PlanPrehranePage();
        break;

      default:
        page = HomePage();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
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