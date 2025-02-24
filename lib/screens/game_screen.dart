import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/location_provider.dart';
import 'scoreboard_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Countdown
  int _countdown = 3;
  Timer? _timer;
  bool _showMap = false; // Nach Ablauf des Countdowns -> Map sichtbar

  // FlutterMap
  final MapController _mapController = MapController();

  // Distanz-Eingabefelder
  final Map<String, TextEditingController> _guessControllers = {};

  // Live-Standort
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  LatLng? _currentLocation; // Blaues Icon

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startNewRound();
    _subscribeToLocation();
  }

  /// Startet den 3-Sekunden-Countdown
  void _startCountdown() {
    _countdown = 3;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          _showMap = true;
        }
      });
    });
  }

  /// Startet eine neue Runde -> ruft im GameProvider `startNextRound()` auf
  Future<void> _startNewRound() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    await gameProvider.startNextRound();

    // Eingabefelder für jeden Spieler neu anlegen
    _guessControllers.clear();
    for (final player in gameProvider.players) {
      _guessControllers[player.name] = TextEditingController();
    }
  }

  /// Abonniert den Live-Standort -> blauer Marker
  Future<void> _subscribeToLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied ||
          permissionGranted == PermissionStatus.deniedForever) {
        permissionGranted = await _location.requestPermission();
      }

      if (permissionGranted == PermissionStatus.granted) {
        // Nur wenn Permission erteilt ist, aktualisieren wir den blauen Marker
        _locationSubscription = _location.onLocationChanged.listen((locData) {
          setState(() {
            _currentLocation = LatLng(
              locData.latitude ?? 0.0,
              locData.longitude ?? 0.0,
            );
          });
        });
      }
    } catch (e) {
      debugPrint('Fehler in subscribeToLocation(): $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Fallback, falls kein Live-Standort
  Future<LatLng> _getCurrentLocationFallback() async {
    if (_currentLocation != null) {
      return _currentLocation!;
    } else {
      final locProv = Provider.of<LocationProvider>(context, listen: false);
      return await locProv.getCurrentLatLng();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final randomLocation = gameProvider.randomLocation;
    final currentRound = gameProvider.currentRound;
    final totalRounds = gameProvider.numberOfRounds;

    return Scaffold(
      appBar: AppBar(
        title: Text('Runde $currentRound / $totalRounds'),
      ),
      body: _countdown > 0 && !_showMap
          ? Center(
              child: Text(
                'Countdown: $_countdown',
                style: const TextStyle(fontSize: 40),
              ),
            )
          : Column(
              children: [
                // --- Karte ---
                Expanded(
                  child: randomLocation == null
                      ? const Center(child: Text('Lade Standort...'))
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: randomLocation,
                            zoom: 2,
                            interactiveFlags: InteractiveFlag.all,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            // Zufälliger Standort (rot)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: randomLocation,
                                  builder: (ctx) => const Icon(
                                    Icons.location_pin,
                                    size: 40,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            // Live-Standort (blau)
                            if (_currentLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentLocation!,
                                    builder: (ctx) => const Icon(
                                      Icons.my_location,
                                      size: 40,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),

                // --- Eingabefelder für alle Spieler ---
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      const Text(
                        'Gib deine Schätzung ein (Entfernung in km):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final player in gameProvider.players)
                        Row(
                          children: [
                            Expanded(child: Text(player.name)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _guessControllers[player.name],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'km',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // --- Button: Runde abschließen ---
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // 1) Eingaben an den Provider
                      for (final player in gameProvider.players) {
                        final guessText = _guessControllers[player.name]?.text ?? '0';
                        final guessValue = double.tryParse(guessText) ?? 0;
                        gameProvider.submitGuess(player.name, guessValue);
                      }

                      // 2) Runde auswerten (Punktevergabe, Distanzberechnung)
                      final isFinished = await gameProvider.finishRound(
                        getCurrentLocation: _getCurrentLocationFallback,
                        onRoundFinished: (round, loc, dist, guesses) {
                          final locProv =
                              Provider.of<LocationProvider>(context, listen: false);
                          locProv.addGameRoundToHistory(
                            round: round,
                            randomLocation: loc,
                            actualDistance: dist,
                            guesses: guesses,
                          );
                        },
                        onGameFinished: (entry) {
                          final locProv =
                              Provider.of<LocationProvider>(context, listen: false);
                          locProv.addFinishedGameToHistory(entry);
                        },
                      );

                      if (!mounted) return;

                      // 3) Dialog mit echter Distanz + Tipps
                      final guessesMap = gameProvider.players.map((p) {
                        final name = p.name;
                        final guess = _guessControllers[p.name]?.text ?? '0';
                        return '$name tippte: $guess km';
                      }).join('\n');

                      final actualDist = gameProvider.lastDistance.toStringAsFixed(2);

                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Runden-Auswertung'),
                          content: Text(
                            'Tatsächliche Distanz: $actualDist km\n\n$guessesMap',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );

                      // 4) Nächste Runde oder Spielende
                      if (!isFinished) {
                        setState(() {
                          _showMap = false;
                        });
                        _startCountdown();
                        await _startNewRound();
                      } else {
                        // Spiel fertig -> Scoreboard
                        if (!mounted) return;
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const ScoreboardScreen()))
                            .then((_) {
                          // zurück zur Hauptseite
                          Navigator.of(context).pop();
                        });
                      }
                    } catch (e) {
                      debugPrint('Fehler in Runde abschließen: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fehler: $e')),
                      );
                    }
                  },
                  child: const Text('Runde abschließen'),
                ),
              ],
            ),
    );
  }
}
