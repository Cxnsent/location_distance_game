import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../models/history_models.dart';

class LocationProvider with ChangeNotifier {
  final Location _location = Location();

  final List<HistoryEntry> _history = [];
  final List<GameHistoryEntry> _gameHistory = [];

  List<HistoryEntry> get history => [..._history];
  List<GameHistoryEntry> get gameHistory => [..._gameHistory];

  /// Versucht, den aktuellen Standort zu ermitteln.
  /// Bei Fehlern (kein Service / Permission) -> (0,0).
  Future<LatLng> getCurrentLatLng() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          debugPrint('User refused to enable location services.');
          throw Exception('Standortdienste nicht aktiviert');
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied ||
          permissionGranted == PermissionStatus.deniedForever) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          debugPrint('User refused location permission.');
          throw Exception('Keine Standortberechtigung erteilt');
        }
      }

      final locationData = await _location.getLocation();
      return LatLng(locationData.latitude ?? 0.0, locationData.longitude ?? 0.0);

    } catch (e) {
      debugPrint('Fehler beim Standortabruf: $e');
      // Fallback (0,0)
      return LatLng(0.0, 0.0);
    }
  }

  /// Runde ins History-Array eintragen
  void addGameRoundToHistory({
    required int round,
    required LatLng randomLocation,
    required double actualDistance,
    required Map<String, double> guesses,
  }) {
    _history.add(
      HistoryEntry(
        start: LatLng(0, 0),
        end: randomLocation,
        distance: actualDistance,
        info: 'Runde $round – ${guesses.length} Tipps',
      ),
    );
    notifyListeners();
  }

  /// Fertiges Spiel in _gameHistory speichern
  void addFinishedGameToHistory(GameHistoryEntry entry) {
    _gameHistory.add(entry);
    notifyListeners();
  }
}
