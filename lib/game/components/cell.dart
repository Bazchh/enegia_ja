import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import '../energy_game.dart';
import '../state/game_state.dart';

class Cell extends PositionComponent
    with TapCallbacks, HasGameReference<EnergyGame> {
  final int cx, cy;

  Cell(this.cx, this.cy);

  @override
  Future<void> onLoad() async {
    size = Vector2.all(game.tileSize);
    position = Vector2(cx * game.tileSize, cy * game.tileSize);
  }

  @override
  void render(Canvas canvas) {
    final model = game.state.grid[cx][cy];
    final ownerColor = game.colorForOwner(model.ownerId);
    final isLocalOwner = model.ownerId == game.localPlayerId;
    final backgroundOpacity = model.b == Building.vazio ? 0.26 : 0.55;
    final background =
        ownerColor.withAlpha((backgroundOpacity * 255).round());

    // base fill tinted by territory
    canvas.drawRect(
      size.toRect(),
      Paint()..color = background,
    );

    // building sprite, if any
    final building = model.b;
    if (building != Building.vazio) {
      final sprite = game.sprites[building]!;
      final rect = size.toRect().deflate(size.x * 0.18);
      sprite.renderRect(canvas, rect);
    }

    // owner border; local player gets stronger accent
    final ownerBorder = game.borderColorForOwner(model.ownerId);
    final borderColor = isLocalOwner
        ? ownerBorder
        : ownerBorder.withAlpha((0.75 * 255).round());
    canvas.drawRect(
      size.toRect().deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );

    // ===== Preview overlays =====
    if (!game.removeMode) {
      // Build: outline green/red depending on budget
      if (model.b == Building.vazio) {
        final selected = game.selecionado ?? Building.solar;
        final canAfford =
            game.localPlayerState.orcamento >= game.costOf(selected);
        canvas.drawRect(
          size.toRect().deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color =
                canAfford ? const Color(0xFF66BB6A) : const Color(0xFFE57373),
        );
      }
    } else {
      // Removal: red stroke and translucent fill
      if (model.b != Building.vazio) {
        canvas.drawRect(
          size.toRect().deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = const Color(0xFFE53935),
        );
        canvas.drawRect(
          size.toRect(),
          Paint()..color = const Color(0x80E53935),
        );
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final res = game.placeAt(cx, cy);
    game.lastPlaceResult = res;
    super.onTapDown(event);
  }
}
