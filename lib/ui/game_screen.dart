import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/energy_game.dart';
import '../game/victory_type.dart';
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
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFFB300), size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Progresso das Vitórias',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // Progresso das vitórias
              Expanded(
                child: _VictoryProgressPanel(game: widget.game),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Continuar Jogando', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Fechar dialog
                      Navigator.of(context).pop(); // Voltar ao menu
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                    ),
                    child: const Text('Sair', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
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

class _VictoryProgressPanel extends StatelessWidget {
  const _VictoryProgressPanel({required this.game});

  final EnergyGame game;

  String _getVictoryName(VictoryType type) {
    switch (type) {
      case VictoryType.sustentavel:
        return 'Sustentável';
      case VictoryType.economica:
        return 'Econômica';
      case VictoryType.cientifica:
        return 'Científica';
      case VictoryType.territorial:
        return 'Territorial';
      case VictoryType.coletiva:
        return 'Coletiva';
    }
  }

  String _getVictoryIcon(VictoryType type) {
    switch (type) {
      case VictoryType.sustentavel:
        return '♻️';
      case VictoryType.economica:
        return '💰';
      case VictoryType.cientifica:
        return '🔬';
      case VictoryType.territorial:
        return '🗺️';
      case VictoryType.coletiva:
        return '🌍';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = game.calculateVictoryProgress();
    final leaders = game.getVictoryLeaders();

    return ListView(
      children: VictoryType.values.map((victoryType) {
        final leaderId = leaders[victoryType];
        final leaderProgress = leaderId != null
            ? (progress[leaderId]?[victoryType] ?? 0.0)
            : 0.0;
        final leaderInitial = leaderId != null ? leaderId.substring(0, 1).toUpperCase() : '?';
        final leaderColor = (leaderId != null && game.hasOwnerColor(leaderId))
            ? game.borderColorForOwner(leaderId)
            : Colors.grey;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              // Círculo de progresso
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fundo cinza
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    // Progresso colorido
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: leaderProgress,
                        strokeWidth: 8,
                        color: leaderColor,
                      ),
                    ),
                    // Letra do líder no centro
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: leaderColor.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: leaderColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          leaderInitial,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: leaderColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Info da vitória
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getVictoryIcon(victoryType),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getVictoryName(victoryType),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Líder: ${leaderId ?? 'Nenhum'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      'Progresso: ${(leaderProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: leaderColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}