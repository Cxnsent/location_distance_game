import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';
import 'providers/game_provider.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const LocationDistanceGame());
}

class LocationDistanceGame extends StatelessWidget {
  const LocationDistanceGame({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(), // Dark Mode
        home: const MainScreen(),
      ),
    );
  }
}