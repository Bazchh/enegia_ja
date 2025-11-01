import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import '../energy_game.dart';
import '../state/game_state.dart';

class Cell extends PositionComponent with TapCallbacks, HasGameRef<EnergyGame> {
  final int cx, cy;

  Cell(this.cx, this.cy);

  @override
  Future<void> onLoad() async {
    size = Vector2.all(gameRef.tileSize);
    position = Vector2(cx * gameRef.tileSize, cy * gameRef.tileSize);
  }

  @override
  void render(Canvas c) {
    final model = gameRef.state.grid[cx][cy];

    // fundo
    c.drawRect(
      size.toRect(),
      Paint()..color = model.powered ? const Color(0xFFFFD54F) : const Color(0xFF424242),
    );

    // ícone (se houver construção)
    final b = model.b;
    if (b != Building.vazio) {
      final sprite = gameRef.sprites[b]!;
      final rect = size.toRect().deflate(size.x * 0.18);
      sprite.renderRect(c, rect);
    }

    // borda padrão
    c.drawRect(
      size.toRect().deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF616161),
    );

    