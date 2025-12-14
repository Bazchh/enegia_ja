import 'package:flutter/material.dart';

import '../game/economy.dart';
import '../game/energy_game.dart';
import '../game/state/game_state.dart';
import '../game/world_events.dart';
import '../multiplayer/multiplayer_game.dart';
import 'scoreboard_screen.dart';

class HUD extends StatefulWidget {
  const HUD({super.key, required this.game});

  final EnergyGame game;

  @override
  State<HUD> createState() => _HUDState();
}

class _HUDState extends State<HUD> {
  bool _hasShownScoreboard = false;
  WorldEvent? _lastNotifiedEvent;

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

      // Verificar se o jogo acabou e mostrar scoreboard em multiplayer
      if (widget.game.state.acabou() &&
          !_hasShownScoreboard &&
          widget.game is MultiplayerGame) {
        _hasShownScoreboard = true;
        _showScoreboard();
      }

      // Notificar sobre novos eventos
      if (widget.game.lastTriggeredEvent != null &&
          widget.game.lastTriggeredEvent != _lastNotifiedEvent) {
        _lastNotifiedEvent = widget.game.lastTriggeredEvent;
        _showEventNotification(_lastNotifiedEvent!);
      }

      setState(() {});
    }
  }

  void _showEventNotification(WorldEvent event) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(event.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    event.description,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFB300),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showScoreboard() {
    if (!context.mounted) return;

    final scores = widget.game.calculateFinalScores();
    final collectiveVictory = widget.game.hasCollectiveVictory();

    // Aguardar um frame para garantir que o contexto está pronto
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ScoreboardScreen(
            scores: scores,
            collectiveVictory: collectiveVictory,
            onNewGame: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final multiplayer = game is MultiplayerGame ? game : null;
    final state = game.state;
    final playerState = game.localPlayerState;

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
                  onShowStats: () => _showStatsSheet(playerState),
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
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Orcamento: ${playerState.orcamento.toStringAsFixed(1)} créditos',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: _EconomyIndicator(
                    economy: playerState.economy,
                    territory: state.getTerritorySize(game.localPlayerId),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _ObjectivesIndicator(metrics: playerState.metrics),
                ),
                if (state.worldState.activeEvents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _ActiveEventsWidget(events: state.worldState.activeEvents),
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

  void _showStatsSheet(PlayerState playerState) {
    final turn = widget.game.state.turno;
    final metrics = playerState.metrics;
    final economy = playerState.economy;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statRow('Turno', '$turn / 20'),
                _statRow('Orcamento', playerState.orcamento.toStringAsFixed(1)),
                const SizedBox(height: 8),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Economia Energética',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                _statRow(
                  'Geracao',
                  '${economy.generation.toStringAsFixed(1)} kWh',
                ),
                _statRow(
                  'Consumo',
                  '${economy.consumption.toStringAsFixed(1)} kWh',
                ),
                _statRow(
                  'Balanco',
                  '${economy.balance >= 0 ? '+' : ''}${economy.balance.toStringAsFixed(1)} kWh',
                  valueColor: economy.balance >= 0 ? Colors.green : Colors.red,
                ),
                _statRow(
                  'Impacto',
                  '${economy.economicImpact >= 0 ? '+' : ''}${economy.economicImpact.toStringAsFixed(1)} creditos',
                  valueColor: economy.economicImpact >= 0 ? Colors.green : Colors.red,
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Métricas ODS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                _statRow(
                  'Acesso',
                  '${(metrics.acessoEnergia * 100).toInt()}%',
                ),
                _statRow(
                  'Energia limpa',
                  '${(metrics.limpa * 100).toInt()}%',
                ),
                _statRow('Tarifa', metrics.tarifa.toStringAsFixed(2)),
                _statRow(
                  'Saude',
                  '${(metrics.saude * 100).toInt()}%',
                ),
                _statRow(
                  'Educacao',
                  '${(metrics.educacao * 100).toInt()}%',
                ),
                _statRow(
                  'Desigualdade',
                  '${(metrics.desigualdade * 100).toInt()}%',
                ),
                _statRow(
                  'Clima',
                  '${(metrics.clima * 100).toInt()}%',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statRow(String label, String value, {Color? valueColor}) {
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
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.bold : null,
            ),
          ),
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
    final affordable = game.localPlayerState.orcamento >= cost;
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
            FilledButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Reiniciar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectivesIndicator extends StatelessWidget {
  const _ObjectivesIndicator({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final acessoOk = metrics.acessoEnergia >= 0.60;
    final limpaOk = metrics.limpa >= 0.60;
    final tarifaOk = metrics.tarifa <= 1.1;
    final allOk = acessoOk && limpaOk && tarifaOk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allOk ? Colors.green : Colors.white30,
          width: allOk ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Objetivos:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          _objectiveChip(
            'Acesso ${(metrics.acessoEnergia * 100).toInt()}%',
            acessoOk,
          ),
          const SizedBox(width: 4),
          _objectiveChip(
            'Limpa ${(metrics.limpa * 100).toInt()}%',
            limpaOk,
          ),
          const SizedBox(width: 4),
          _objectiveChip(
            'Tarifa ${metrics.tarifa.toStringAsFixed(2)}',
            tarifaOk,
          ),
        ],
      ),
    );
  }

  Widget _objectiveChip(String label, bool achieved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: achieved
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: achieved ? Colors.green : Colors.red.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            achieved ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: achieved ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: achieved ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EconomyIndicator extends StatelessWidget {
  const _EconomyIndicator({
    required this.economy,
    required this.territory,
  });

  final PlayerEconomy economy;
  final int territory;

  @override
  Widget build(BuildContext context) {
    final hasBalance = economy.balance != 0;
    final isSurplus = economy.balance > 0;
    final balanceColor = isSurplus ? Colors.green : Colors.red;
    final balanceIcon = isSurplus ? Icons.arrow_upward : Icons.arrow_downward;

    return Row(
      children: [
        // Ícone de status energético
        Icon(
          balanceIcon,
          color: hasBalance ? balanceColor : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 4),
        // Geração vs Consumo
        Expanded(
          child: Text(
            '⚡ ${economy.generation.toStringAsFixed(0)}/${economy.consumption.toStringAsFixed(0)} kWh',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ),
        // Território
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_on, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '$territory',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Impacto econômico
        if (hasBalance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: balanceColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: balanceColor, width: 1),
            ),
            child: Text(
              '${economy.economicImpact >= 0 ? '+' : ''}${economy.economicImpact.toStringAsFixed(1)}',
              style: TextStyle(
                color: balanceColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveEventsWidget extends StatelessWidget {
  const _ActiveEventsWidget({required this.events});

  final List<ActiveEvent> events;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: events.map((activeEvent) {
        final event = activeEvent.event;
        return Tooltip(
          message: '${event.description}\n${activeEvent.turnsRemaining} turnos restantes',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFB300),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(event.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${activeEvent.turnsRemaining}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
