import 'package:flutter/material.dart';

import '../game/energy_game.dart';
import '../game/state/game_state.dart';
import '../multiplayer/multiplayer_game.dart';

class HUD extends StatefulWidget {
  const HUD({super.key, required this.game});

  final EnergyGame game;

  @override
  State<HUD> createState() => _HUDState();
}

class _HUDState extends State<HUD> {
  @override
  void initState() {
    super.initState();
    _listenForBudgetWarnings();
  }

  void _listenForBudgetWarnings() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) break;

      if (widget.game.lastPlaceResult == PlaceResult.semOrcamento) {
        widget.game.lastPlaceResult = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Orcamento insuficiente'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final multiplayer = game is MultiplayerGame ? game : null;
    final state = game.state;

    final canAct = multiplayer == null || multiplayer.canAct;
    final hasEndedTurn = multiplayer?.hasEndedTurn ?? false;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  state: state,
                  game: game,
                  multiplayer: multiplayer,
                  onShowStats: () => _showStatsSheet(state),
                ),
                if (multiplayer != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Turno ${state.turno} - Prontos ${multiplayer.readiness.values.where((r) => r).length}/${multiplayer.readiness.length}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                const Spacer(),
                if (multiplayer != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      hasEndedTurn
                          ? 'Aguardando outros jogadores...'
                          : 'Seu turno esta ativo',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                _BuildPalette(
                  game: game,
                  canAct: canAct,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 96),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'end-turn',
                tooltip: hasEndedTurn
                    ? 'Aguardando outros jogadores'
                    : 'Encerrar turno',
                backgroundColor: hasEndedTurn
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.primary,
                onPressed: canAct ? () => setState(() => game.endTurn()) : null,
                child: Icon(
                  hasEndedTurn ? Icons.hourglass_empty : Icons.check,
                  color: Colors.white,
                ),
              ),
            ),
            if (state.acabou())
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _ResultBar(
                    state: state,
                    onRestart: () => setState(() => game.restart()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStatsSheet(GameState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statRow('Turno', '${state.turno} / 20'),
              _statRow('Orcamento', state.orcamento.toStringAsFixed(1)),
              _statRow(
                'Acesso',
                '${(state.metrics.acessoEnergia * 100).toInt()}%',
              ),
              _statRow(
                'Energia limpa',
                '${(state.metrics.limpa * 100).toInt()}%',
              ),
              _statRow('Tarifa', state.metrics.tarifa.toStringAsFixed(2)),
              _statRow(
                'Saude',
                '${(state.metrics.saude * 100).toInt()}%',
              ),
              _statRow(
                'Educacao',
                '${(state.metrics.educacao * 100).toInt()}%',
              ),
              _statRow(
                'Desigualdade',
                '${(state.metrics.desigualdade * 100).toInt()}%',
              ),
              _statRow(
                'Clima',
                '${(state.metrics.clima * 100).toInt()}%',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.game,
    required this.multiplayer,
    required this.onShowStats,
  });

  final GameState state;
  final EnergyGame game;
  final MultiplayerGame? multiplayer;
  final VoidCallback onShowStats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: multiplayer == null
                ? Text(
                    'Turno ${state.turno} / 20',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white),
                  )
                : _TurnIndicators(
                    multiplayer: multiplayer!,
                    game: game,
                  ),
          ),
          IconButton(
            tooltip: 'Estatisticas',
            onPressed: onShowStats,
            icon: const Icon(
              Icons.bar_chart,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnIndicators extends StatelessWidget {
  const _TurnIndicators({
    required this.multiplayer,
    required this.game,
  });

  final MultiplayerGame multiplayer;
  final EnergyGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerIds = multiplayer.players;
    if (playerIds.isEmpty) {
      return Text(
        'Turno ${multiplayer.state.turno} / 20',
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: playerIds.map((playerId) {
          final ready = multiplayer.readiness[playerId] ?? false;
          final isLocal = playerId == multiplayer.socket.playerId;
          final label =
              isLocal ? 'Voce' : playerId.substring(0, 4).toUpperCase();
          final border = multiplayer.borderColorForOwner(playerId);
          final background = ready
              ? border.withAlpha((0.28 * 255).round())
              : border.withAlpha((0.75 * 255).round());
          final icon = ready ? Icons.check : Icons.flash_on;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: background,
                  foregroundColor: Colors.white,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BuildPalette extends StatelessWidget {
  const _BuildPalette({
    required this.game,
    required this.canAct,
    required this.onChanged,
  });

  final EnergyGame game;
  final bool canAct;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildButton(
                context,
                label: 'Solar',
                building: Building.solar,
                asset: 'assets/images/icons/icon_solar.png',
                tooltip: 'Gera energia limpa constante',
              ),
              _buildButton(
                context,
                label: 'Eolica',
                building: Building.eolica,
                asset: 'assets/images/icons/icon_wind.png',
                tooltip: 'Energia limpa com tarifa menor',
              ),
              _buildButton(
                context,
                label: 'Eficiencia',
                building: Building.eficiencia,
                asset: 'assets/images/icons/icon_efficiency.png',
                tooltip: 'Reduz tarifas e melhora educacao',
              ),
              _buildButton(
                context,
                label: 'Saneamento',
                building: Building.saneamento,
                asset: 'assets/images/icons/icon_sanitation.png',
                tooltip: 'Melhora saude e reduz desigualdade',
              ),
              const SizedBox(width: 12),
              _removalButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required Building building,
    required String asset,
    required String tooltip,
  }) {
    final cost = game.costOf(building);
    final affordable = game.state.orcamento >= cost;
    final selected = game.selecionado == building && !game.removeMode;

    void handleTap() {
      game.removeMode = false;
      game.selecionado = building;
      onChanged();
    }

    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: 20, height: 20),
        const SizedBox(width: 8),
        Text(label),
        const SizedBox(width: 6),
        Text(
          '(${cost.toStringAsFixed(0)})',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: affordable ? Colors.white70 : Colors.redAccent,
          ),
        ),
      ],
    );

    final button = selected
        ? FilledButton(
            onPressed: affordable && canAct ? handleTap : null,
            child: buttonChild,
          )
        : FilledButton.tonal(
            onPressed: affordable && canAct ? handleTap : null,
            child: buttonChild,
          );

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: '$tooltip\nCusto: ${cost.toStringAsFixed(1)}',
        waitDuration: const Duration(milliseconds: 250),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          scale: selected ? 1.05 : 1.0,
          curve: Curves.easeOut,
          child: button,
        ),
      ),
    );
  }

  Widget _removalButton(BuildContext context) {
    final active = game.removeMode;
    final icon = Icon(Icons.delete, color: active ? Colors.white : null);
    final label = Text(
      'Remover',
      style: TextStyle(color: active ? Colors.white : null),
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        label,
      ],
    );

    final button = active
        ? FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: canAct
                ? () {
                    game.removeMode = false;
                    onChanged();
                  }
                : null,
            child: child,
          )
        : FilledButton.tonal(
            onPressed: canAct
                ? () {
                    game.removeMode = true;
                    onChanged();
                  }
                : null,
            child: child,
          );

    return Tooltip(
      message:
          'Alterna para remover construcoes e recuperar 50% do custo',
      waitDuration: const Duration(milliseconds: 250),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: active ? 1.05 : 1.0,
        curve: Curves.easeOut,
        child: button,
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.state,
    required this.onRestart,
  });

  final GameState state;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final won = state.venceu();
    final color = won ? Colors.green : Colors.red;
    final title = won ? 'Vitoria sustentavel!' : 'Objetivos nao alcancados';

    return Card(
      color: color.withAlpha((0.12 * 255).round()),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(won ? Icons.check_circle : Icons.cancel, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton(
              onPressed: onRestart,
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      ),
    );
  }
}
