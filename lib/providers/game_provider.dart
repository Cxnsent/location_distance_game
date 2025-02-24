import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart'; // Für Reverse-Geocoding
import '../models/history_models.dart';

class GameProvider with ChangeNotifier {
  int _numberOfRounds = 1;
  int _currentRound = 0;

  // Liste der Spieler
  final List<Player> _players = [];

  // Zufälliger Standort, der pro Runde generiert wird
  LatLng? _randomLocation;

  // Distanz-Tipps: playerName -> guessedDistance
  final Map<String, double> _distanceGuesses = {};

  bool _gameFinished = false;

  // Letzte Distanz für den Auswertungsdialog
  double? _lastDistance;
  double get lastDistance => _lastDistance ?? 0.0;

  int get numberOfRounds => _numberOfRounds;
  int get currentRound => _currentRound;
  List<Player> get players => _players;
  LatLng? get randomLocation => _randomLocation;
  bool get gameFinished => _gameFinished;

  /// Einstellungen setzen (Spieler, Runden)
  void setupGame(List<String> playerNames, int roundsCount) {
    _players.clear();
    for (final name in playerNames) {
      _players.add(Player(name: name));
    }
    _numberOfRounds = roundsCount;
    _currentRound = 0;
    _gameFinished = false;
    _lastDistance = null;
    notifyListeners();
  }

  /// Nächste Runde starten -> pro Runde ein NEUER Zufallsstandort!
  Future<void> startNextRound() async {
    if (_currentRound >= _numberOfRounds) {
      return;
    }
    _currentRound++;

    // Hier wird in jeder Runde ein neuer Standort generiert
    _randomLocation = await _generateRandomLandLocation();

    // Alte Tipps zurücksetzen
    _distanceGuesses.clear();
    notifyListeners();
  }

  /// Spieler gibt Tipp ab (Entfernung in km)
  void submitGuess(String playerName, double guessedDistance) {
    _distanceGuesses[playerName] = guessedDistance;
  }

  /// Runde abschließen: Punkte verteilen, History updaten
  /// Gibt `true` zurück, wenn das Spiel komplett vorbei ist
  Future<bool> finishRound({
    required Future<LatLng> Function() getCurrentLocation,
    required void Function(int round, LatLng loc, double dist, Map<String, double> guesses)
        onRoundFinished,
    required void Function(GameHistoryEntry entry) onGameFinished,
  }) async {
    if (_randomLocation == null) {
      throw Exception('Kein Zufallsstandort vorhanden');
    }

    // Standort abrufen (kann 0,0 sein, falls Permission abgelehnt)
    final currentLocation = await getCurrentLocation();

    // Tatsächliche Distanz
    final actualDistance = _calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      _randomLocation!.latitude,
      _randomLocation!.longitude,
    );
    _lastDistance = actualDistance;

    // Differenz pro Spieler
    final Map<String, double> differences = {};
    _distanceGuesses.forEach((playerName, guess) {
      differences[playerName] = (guess - actualDistance).abs();
    });

    // Sortieren nach kleinstem Fehler
    final sortedEntries = differences.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Punkteverteilung
    final List<int> pointPattern = [100, 80, 60, 40, 20];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final p = _players.firstWhere((pl) => pl.name == entry.key);
      p.points += (i < pointPattern.length) ? pointPattern[i] : 0;
    }

    // Runde ins History loggen
    onRoundFinished(_currentRound, _randomLocation!, actualDistance, _distanceGuesses);

    // Prüfen, ob das Spiel vorbei ist
    if (_currentRound >= _numberOfRounds) {
      _gameFinished = true;

      // Gesamtes Spiel speichern
      final entry = GameHistoryEntry(
        numberOfPlayers: _players.length,
        numberOfRounds: _numberOfRounds,
        timestamp: DateTime.now(),
        players: _players
            .map((p) => PlayerResult(name: p.name, points: p.points))
            .toList(),
      );
      onGameFinished(entry);

      notifyListeners();
      return true;
    }

    notifyListeners();
    return false;
  }

  /// Generiert eine zufällige Koordinate auf Land (max. 10 Versuche).
  /// Falls wir nur Wasser finden, fallback (z. B. München).
  Future<LatLng> _generateRandomLandLocation() async {
    final rand = math.Random();

    for (int i = 0; i < 10; i++) {
      double lat = -60 + rand.nextDouble() * 130;   // -60..+70
      double lon = -170 + rand.nextDouble() * 340;  // -170..+170

      try {
        final placemarks = await placemarkFromCoordinates(lat, lon);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          // Wenn Land gefunden -> akzeptieren
          if (pm.country != null && pm.country!.isNotEmpty) {
            return LatLng(lat, lon);
          }
        }
      } catch (_) {
        // Vermutlich Wasser -> neuer Versuch
      }
    }

    // Fallback, z. B. München
    return LatLng(48.137154, 11.576124);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Erd-Radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _degToRad(double degree) => degree * (math.pi / 180);
}

/// Einfacher Player
class Player {
  final String name;
  double points;

  Player({required this.name, this.points = 0});
}
