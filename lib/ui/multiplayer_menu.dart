import 'package:flutter/material.dart';

import '../multiplayer/lobby_controller.dart';
import 'lobby_screen.dart';

class MultiplayerMenu extends StatefulWidget {
  const MultiplayerMenu({super.key});

  @override
  State<MultiplayerMenu> createState() => _MultiplayerMenuState();
}

class _MultiplayerMenuState extends State<MultiplayerMenu> {
  final TextEditingController _roomController = TextEditingController();
  bool _isCreatingRoom = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Energia Ja! - Multiplayer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Modo Multiplayer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Criar Sala'),
                    selected: _isCreatingRoom,
                    onSelected: (selected) {
                      setState(() {
                        _isCreatingRoom = true;
                      });
                    },
                  ),
                  const SizedBox(width: 20),
                  ChoiceChip(
                    label: const Text('Entrar em Sala'),
                    selected: !_isCreatingRoom,
                    onSelected: (selected) {
                      setState(() {
                        _isCreatingRoom = false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (!_isCreatingRoom)
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(
                    labelText: 'ID da Sala',
                    border: OutlineInputBorder(),
                    hintText: 'Digite o ID da sala para entrar',
                  ),
                ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: () {
                  if (_isCreatingRoom) {
                    _createRoom();
                  } else {
                    _joinRoom();
                  }
                },
                child: Text(_isCreatingRoom ? 'Criar Sala' : 'Entrar na Sala'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createRoom() {
    final controller = LobbyController(isHost: true);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LobbyScreen(controller: controller),
      ),
    );
  }

  void _joinRoom() {
    final roomId = _roomController.text.trim();
    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite o ID da sala')),
      );
      return;
    }

    final controller = LobbyController(roomId: roomId, isHost: false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LobbyScreen(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}
