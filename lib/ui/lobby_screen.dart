import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../multiplayer/lobby_controller.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.controller});

  final LobbyController controller;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final LobbyController _controller;
  final TextEditingController _chatController = TextEditingController();
  bool _navigated = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_handleControllerUpdate);
    _controller.initialize().whenComplete(() {
      if (mounted) {
        setState(() => _initializing = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdate);
    _chatController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (!mounted) return;
    if (_controller.gameStarting && !_navigated) {
      _navigated = true;
      final game = _controller.buildGame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GameScreen(game: game)),
        );
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_initializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conectando ao lobby...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final error = _controller.errorMessage;
    final countdown = _controller.countdownSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby Multiplayer'),
        actions: [
          IconButton(
            tooltip: 'Copiar ID da sala',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _controller.roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID copiado para a area de transferencia')), // ascii friendly
              );
            },
            icon: const Icon(Icons.copy),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Sala: ${_controller.roomId}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                      title: Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ),
              if (countdown != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Chip(
                    label: Text(
                      countdown >= 0
                          ? 'Partida inicia em $countdown s'
                          : 'Contagem cancelada',
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 720;
                    final playersSection = _buildPlayersSection(theme);
                    if (isWide) {
                      final chatSection = _buildChatSection(theme);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: playersSection),
                          const SizedBox(width: 16),
                          Expanded(child: chatSection),
                        ],
                      );
                    }
                    final chatSection = _buildChatSection(theme);
                    return Column(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: playersSection,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: chatSection),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildReadyRow(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayersSection(ThemeData theme) {
    final players = _controller.players;
    final localId = _controller.socket.playerId;
    final localPlayer = _controller.localPlayer;
    final colors = _controller.availableColors;

    Widget playersList;
    if (players.isEmpty) {
      playersList = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Aguardando jogadores entrarem na sala...',
          style: theme.textTheme.bodyMedium,
        ),
      );
    } else {
      playersList = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: players.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final player = players[index];
            final isLocal = player.id == localId;
            final ready = player.ready;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _colorFromHex(player.color),
                child: Text(
                  player.id.substring(0, 2).toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                isLocal
                    ? 'Você (${player.id.substring(0, 6)})'
                    : player.id.substring(0, 8),
              ),
              trailing: Icon(
                ready ? Icons.check_circle : Icons.hourglass_bottom,
                color: ready ? theme.colorScheme.primary : theme.disabledColor,
              ),
            );
          },
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jogadores (${players.length})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            playersList,
            if (localPlayer != null) ...[
              const SizedBox(height: 16),
              Text('Escolha sua cor', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors
                    .map(
                      (color) => ChoiceChip(
                        label: const SizedBox(width: 28, height: 28),
                        selected: localPlayer.color == color,
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: _colorFromHex(color),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            _controller.setColor(color);
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatSection(ThemeData theme) {
    final chat = _controller.chatMessages;

    final messages = ListView.builder(
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: chat.length,
      itemBuilder: (context, index) {
        final message = chat[index];
        final playerTag = message.playerId.substring(0, 6).toUpperCase();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$playerTag: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: message.message),
              ],
            ),
          ),
        );
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: chat.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Nenhuma mensagem ainda.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : messages,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendChat(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendChat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyRow(ThemeData theme) {
    final isReady = _controller.isLocalReady;
    final label = isReady ? 'Pronto' : 'Pronto?';

    return Row(
      children: [
        Expanded(
          child: Text(
            isReady
                ? 'Aguardando outros jogadores...'
                : 'Clique em pronto quando finalizar suas configuracoes.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: _controller.gameStarting ? null : _controller.toggleReady,
          child: Text(label),
        ),
      ],
    );
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _controller.sendChat(text);
    _chatController.clear();
  }

  Color _colorFromHex(String hex) {
    var value = hex.toUpperCase().replaceAll('#', '');
    if (value.length == 6) {
      value = 'FF$value';
    }
    return Color(int.parse(value, radix: 16));
  }
}
