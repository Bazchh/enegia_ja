import 'package:flutter/material.dart';
import '../game/victory_type.dart';

class ScoreboardScreen extends StatelessWidget {
  final List<PlayerScore> scores;
  final bool collectiveVictory;
  final VoidCallback onNewGame;

  const ScoreboardScreen({
    super.key,
    required this.scores,
    required this.collectiveVictory,
    required this.onNewGame,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedScores = List<PlayerScore>.from(scores)
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking Final'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Vitória Coletiva (se aplicável)
            if (collectiveVictory)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '🌍',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'VITÓRIA COLETIVA!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Todos mantiveram o clima saudável',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

            // Ranking de jogadores
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedScores.length,
                itemBuilder: (context, index) {
                  final score = sortedScores[index];
                  final position = index + 1;
                  return _PlayerCard(
                    score: score,
                    position: position,
                    isWinner: position == 1,
                  );
                },
              ),
            ),

            // Botão Nova Partida
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNewGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Nova Partida'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerScore score;
  final int position;
  final bool isWinner;

  const _PlayerCard({
    required this.score,
    required this.position,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(int.parse('0xFF${score.color.substring(1)}'));
    // Avoid RangeError when the player id is shorter than 6 characters
    final displayId = score.playerId.length > 6
        ? score.playerId.substring(0, 6)
        : score.playerId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isWinner
          ? const Color(0xFFFFB300).withValues(alpha: 0.2)
          : theme.cardColor,
      elevation: isWinner ? 8 : 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com posição e nome
            Row(
              children: [
                _PositionBadge(position: position, isWinner: isWinner),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Jogador ${displayId.toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${score.totalScore.toStringAsFixed(0)} pts',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFB300),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Vitórias conquistadas
            if (score.victories.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: score.victories.map((victory) {
                  final condition = VictoryCondition.all.firstWhere(
                    (c) => c.type == victory,
                  );
                  return Chip(
                    avatar: Text(condition.icon),
                    label: Text(
                      condition.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: const Color(0xFFFFB300).withValues(alpha: 0.3),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Estatísticas
            _StatRow(
              icon: '♻️',
              label: 'Sustentabilidade',
              value: '${(score.sustentabilidade * 100).toInt()}%',
            ),
            _StatRow(
              icon: '💰',
              label: 'Orçamento',
              value: score.economia.toStringAsFixed(1),
            ),
            _StatRow(
              icon: '🔬',
              label: 'Eficiência',
              value: '${(score.ciencia * 100).toInt()}%',
            ),
            _StatRow(
              icon: '🗺️',
              label: 'Território',
              value: '${score.territorio} células',
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  final int position;
  final bool isWinner;

  const _PositionBadge({
    required this.position,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinner
        ? const Color(0xFFFFB300)
        : position == 2
            ? const Color(0xFFB0B0B0)
            : position == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFF666666);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isWinner
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          position == 1 ? '👑' : '$position°',
          style: TextStyle(
            color: isWinner ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFB300),
            ),
          ),
        ],
      ),
    );
  }
}
