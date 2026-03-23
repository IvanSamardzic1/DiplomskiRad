import 'package:flutter/material.dart';
import 'home.dart';
import 'namirnice.dart';
import 'plan_obroka.dart';
import 'trgovina.dart';

void main() {
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

      home: const MyHomePage(title: 'Aplikacija za praćenje namirnica'),
      debugShowCheckedModeBanner: false,
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
        page = NamirnicePage(); // Stranica s namirnicama
        break;
      case 2:
        page = PlanObrokaPage(); // Stranica s planom obroka
        break;
      case 3:
        page = TrgovinaPage(); // Stranica s trgovinom
        break;

      default:
        page = HomePage();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
            icon: Icon(Icons.fastfood),
            label: 'Moje namirnice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Plan obroka',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Trgovina',
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