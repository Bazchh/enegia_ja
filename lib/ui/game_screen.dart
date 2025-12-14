import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/energy_game.dart';
import '../multiplayer/multiplayer_game.dart';
import 'hud.dart';

class GameScreen extends StatefulWidget {
  final EnergyGame game;

  const GameScreen({super.key, required this.game});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Set<String> _knownPlayers = {};

  @override
  void initState() {
    super.initState();
    _setupPlayerMonitoring();
  }

  void _setupPlayerMonitoring() {
    if (widget.game is MultiplayerGame) {
      final multiGame = widget.game as MultiplayerGame;
      _knownPlayers.addAll(multiGame.players);

      // Monitorar mudanças nos jogadores
      _checkForPlayerChanges();
    }
  }

  void _checkForPlayerChanges() async {
    if (widget.game is! MultiplayerGame) return;

    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) break;

      final multiGame = widget.game as MultiplayerGame;
      final currentPlayers = multiGame.players.toSet();

      // Detectar jogadores que saíram
      final leftPlayers = _knownPlayers.difference(currentPlayers);
      for (final playerId in leftPlayers) {
        if (mounted && playerId != multiGame.socket.playerId) {
          _showPlayerLeftNotification(playerId);
        }
      }

      // Atualizar lista conhecida
      _knownPlayers
        ..clear()
        ..addAll(currentPlayers);
    }
  }

  void _showPlayerLeftNotification(String playerId) {
    final shortId = playerId.substring(0, 6).toUpperCase();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Jogador $shortId saiu da partida'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showExitMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Partida'),
        content: const Text('Deseja realmente sair? O progresso será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fechar dialog
              Navigator.of(context).pop(); // Voltar ao menu
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: widget.game),
          HUD(game: widget.game),
          // Botão de menu no canto superior direito
          SafeArea(
            child: Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: _showExitMenu,
                tooltip: 'Menu',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}