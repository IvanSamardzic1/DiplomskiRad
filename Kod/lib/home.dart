import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //Naslov stranice
        title: Text('Početna stranica'),
      ),
      body: Stack(
        //Pozadina
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
            //Tekst, odnosno početna poruka koja se nalazi na sredini ekrana
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Dobrodošli u aplikaciju za praćenje namirnica! U ovoj aplikaciji možete '
                        'pratiti namirnice koje imate kod kuće, planirati obroke za naredni tjedan i praviti popis za kupovinu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}