import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final players = gameProvider.players;

    // Sortiere Spieler nach Punkten (absteigend)
    final sortedPlayers = [...players]..sort((a, b) => b.points.compareTo(a.points));

    return Scaffold(
      appBar: AppBar(title: const Text('Scoreboard')),
      body: ListView.builder(
        itemCount: sortedPlayers.length,
        itemBuilder: (context, index) {
          final player = sortedPlayers[index];
          return ListTile(
            leading: Text('#${index + 1}'),
            title: Text(player.name),
            trailing: Text('${player.points} Punkte'),
          );
        },
      ),
    );
  }
}
