import 'package:flutter/material.dart';
import '../multiplayer/multiplayer_game.dart';
import 'game_screen.dart';

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
        title: const Text('Energia Já! - Multiplayer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Título
              const Text(
                'Modo Multiplayer',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // Opções
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
              
              // Campo de entrada para ID da sala (apenas para entrar)
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
              
              // Botão de ação
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
    // Cria um novo jogo multiplayer como host
    final game = MultiplayerGame(isHost: true);
    
    // Mostra o ID da sala
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ID da sala: ${game.socket.roomId}'),
        action: SnackBarAction(
          label: 'Copiar',
          onPressed: () {
            // Em uma implementação real, copiaria para a área de transferência
          },
        ),
      ),
    );
    
    // Navega para a tela do jogo
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(game: game),
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
    
    // Cria um jogo multiplayer como participante
    final game = MultiplayerGame(roomId: roomId);
    
    // Navega para a tela do jogo
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(game: game),
      ),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }
}