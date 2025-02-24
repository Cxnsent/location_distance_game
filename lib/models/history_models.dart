import 'package:latlong2/latlong.dart';

/// Einzelne Runden
class HistoryEntry {
  final LatLng start;
  final LatLng end;
  final double distance;
  final String? info;

  HistoryEntry({
    required this.start,
    required this.end,
    required this.distance,
    this.info,
  });
}

/// Ein ganzes Spiel
class GameHistoryEntry {
  final int numberOfPlayers;
  final int numberOfRounds;
  final DateTime timestamp;
  final List<PlayerResult> players;

  GameHistoryEntry({
    required this.numberOfPlayers,
    required this.numberOfRounds,
    required this.timestamp,
    required this.players,
  });
}

/// Ergebnis eines einzelnen Spielers
class PlayerResult {
  final String name;
  final double points;

  PlayerResult({required this.name, required this.points});
}
