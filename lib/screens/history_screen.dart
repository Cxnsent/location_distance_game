import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/location_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  Future<String> _getAddress(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final country = pm.country ?? 'Unbekanntes Land';
        final city = pm.locality?.isNotEmpty == true
            ? pm.locality
            : (pm.administrativeArea?.isNotEmpty == true
                ? pm.administrativeArea
                : 'Unbekannte Stadt');
        return '$country / $city\n($lat, $lon)';
      }
    } catch (_) {}
    return 'Unbekannt\n($lat, $lon)';
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final url = 'https://www.google.com/maps?q=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final roundHistory = locationProvider.history;
    final gameHistory = locationProvider.gameHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verlauf'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              'Runden-Verlauf',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (roundHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Keine Einträge'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roundHistory.length,
                itemBuilder: (context, index) {
                  final entry = roundHistory[index];
                  return FutureBuilder<String>(
                    future: _getAddress(entry.end.latitude, entry.end.longitude),
                    builder: (context, snapshot) {
                      final address = snapshot.data ?? 'Lädt...';
                      return ListTile(
                        title: Text(entry.info ?? 'Runde ${index + 1}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Standort: $address'),
                            Text('Distanz: ${entry.distance.toStringAsFixed(2)} km'),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => _openGoogleMaps(
                                  entry.end.latitude,
                                  entry.end.longitude,
                                ),
                                child: const Text('Auf Google Maps öffnen'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            const Divider(),
            const Text(
              'Gesamte Spiele',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (gameHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Keine fertigen Spiele'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gameHistory.length,
                itemBuilder: (context, index) {
                  final game = gameHistory[index];
                  final date = game.timestamp.toLocal().toString();
                  return ListTile(
                    title: Text('Spiel vom $date'),
                    subtitle: Text(
                      '${game.numberOfPlayers} Spieler, ${game.numberOfRounds} Runden',
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('Ergebnisse Spiel #${index + 1}'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: game.players.map((p) {
                              return Text('${p.name}: ${p.points} Punkte');
                            }).toList(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
