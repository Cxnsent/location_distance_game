import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({Key? key}) : super(key: key);

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final TextEditingController _roundsController = TextEditingController(text: '3');
  int _numberOfPlayers = 2;

  // TextController pro Spieler
  List<TextEditingController> _playerNameControllers = [];

  @override
  void initState() {
    super.initState();
    _initPlayerControllers();
  }

  void _initPlayerControllers() {
    _playerNameControllers = List.generate(_numberOfPlayers, (index) {
      return TextEditingController(text: 'Spieler ${index + 1}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spiel Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Anzahl Spieler
              Row(
                children: [
                  const Text('Anzahl Spieler: '),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _numberOfPlayers,
                    items: List.generate(8, (i) => i + 1)
                        .map((val) => DropdownMenuItem<int>(
                              value: val,
                              child: Text(val.toString()),
                            ))
                        .toList(),
                    onChanged: (newVal) {
                      if (newVal == null) return;
                      setState(() {
                        _numberOfPlayers = newVal;
                        _initPlayerControllers();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Runden
              TextField(
                controller: _roundsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Anzahl Runden'),
              ),
              const SizedBox(height: 16),
              // Spielernamen
              for (int i = 0; i < _numberOfPlayers; i++)
                TextField(
                  controller: _playerNameControllers[i],
                  decoration: InputDecoration(labelText: 'Name Spieler ${i + 1}'),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final roundsCount = int.tryParse(_roundsController.text) ?? 1;
                  final playerNames = _playerNameControllers
                      .map((controller) => controller.text.trim())
                      .toList();

                  final gameProvider = Provider.of<GameProvider>(context, listen: false);
                  gameProvider.setupGame(playerNames, roundsCount);

                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                },
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
