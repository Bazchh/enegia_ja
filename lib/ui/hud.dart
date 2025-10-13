import 'package:flutter/material.dart';
import '../game/energy_game.dart';
import '../game/state/game_state.dart';

class HUD extends StatefulWidget {
  final EnergyGame game;
  const HUD({super.key, required this.game});
  @override
  State<HUD> createState() => _HUDState();
}

class _HUDState extends State<HUD> {
  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) break;

      // snackbar rápido quando faltar orçamento
      final res = widget.game.lastPlaceResult;
      if (res == PlaceResult.semOrcamento) {
        widget.game.lastPlaceResult = null;
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Orçamento insuficiente')),
          );
        }
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.game.state;
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(s),
            const Spacer(),
            if (s.acabou()) _resultBar(s) else _buildBar(s),
          ],
        ),
      ),
    );
  }

  Widget _topBar(GameState s) {
    text(String t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(t),
        );
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 12,
          runSpacing: 6,
          children: [
            text("Turno: ${s.turno} / 20"),
            text("Orçamento: ${s.orcamento.toStringAsFixed(1)}"),
            text("Acesso: ${(s.metrics.acessoEnergia * 100).toInt()}%"),
            text("Limpa: ${(s.metrics.limpa * 100).toInt()}%"),
            text("Tarifa: ${s.metrics.tarifa.toStringAsFixed(2)}"),
            text("Saúde: ${(s.metrics.saude * 100).toInt()}%"),
            text("Educação: ${(s.metrics.educacao * 100).toInt()}%"),
            text("Melhor Limpa: ${(widget.game.bestClean * 100).toInt()}%"),
            text(
                "Melhor Turno: ${widget.game.bestTurn == 999 ? '-' : widget.game.bestTurn}"),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(GameState s) {
    final g = widget.game;

    // Agora com tooltip e animação de seleção + disabled quando não cabe no orçamento
    Widget btnBuild(String label, Building b, String asset, String tooltip) {
      final cost = g.costOf(b);
      final affordable = s.orcamento >= cost;
      final selected = g.selecionado == b && !g.removeMode;

      final buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 20, height: 20),
          const SizedBox(width: 8),
          Text(label),
          const SizedBox(width: 6),
          Text(
            "(${cost.toStringAsFixed(0)})",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: affordable ? Colors.white70 : Colors.redAccent,
            ),
          ),
        ],
      );

      final onTap = () => setState(() {
            g.removeMode = false; // ao escolher construir, sai do modo remover
            g.selecionado = b;
          });

      final button = selected
          ? FilledButton(onPressed: affordable ? onTap : null, child: buttonChild)
          : FilledButton.tonal(onPressed: affordable ? onTap : null, child: buttonChild);

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

    // BOTÃO REMOVER (toggle) com tooltip e animação
    Widget btnRemove() {
      final active = g.removeMode;
      final icon = Icon(Icons.delete, color: active ? Colors.white : null);
      final label = Text('Remover',
          style: TextStyle(color: active ? Colors.white : null));

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
              onPressed: () => setState(() => g.removeMode = false),
              child: child,
            )
          : FilledButton.tonal(
              onPressed: () => setState(() => g.removeMode = true),
              child: child,
            );

      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Tooltip(
          message: 'Alterna para remover construções e recuperar 50% do custo',
          waitDuration: const Duration(milliseconds: 250),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: active ? 1.05 : 1.0,
            curve: Curves.easeOut,
            child: button,
          ),
        ),
      );
    }

    // caminhos completos para Image.asset (ajustado p/ assets/images/icons)
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 56,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                btnBuild(
                  "Solar",
                  Building.solar,
                  'assets/images/icons/icon_solar.png',
                  'Gera energia limpa constante',
                ),
                btnBuild(
                  "Eólica",
                  Building.eolica,
                  'assets/images/icons/icon_wind.png',
                  'Energia limpa com tarifa levemente menor',
                ),
                btnBuild(
                  "Eficiência",
                  Building.eficiencia,
                  'assets/images/icons/icon_efficiency.png',
                  'Reduz tarifas e melhora educação',
                ),
                btnBuild(
                  "Saneamento",
                  Building.saneamento,
                  'assets/images/icons/icon_sanitation.png',
                  'Melhora saúde e reduz desigualdade',
                ),
                const SizedBox(width: 8),
                btnRemove(),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => setState(() => widget.game.endTurn()),
                  child: const Text('Avançar turno'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBar(GameState s) {
    final venceu = s.venceu();
    final title = venceu ? "Vitória sustentável!" : "Objetivos não alcançados";
    final color = venceu ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.all(8),
      color: color.withOpacity(0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(venceu ? Icons.check_circle : Icons.cancel, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              onPressed: () => setState(() => widget.game.restart()),
              child: const Text("Reiniciar"),
            )
          ],
        ),
      ),
    );
  }
}
