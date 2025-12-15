import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

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
    final visibility = game.getCellVisibility(cx, cy);

    // Se célula não foi explorada, renderizar apenas escuro total
    if (visibility == VisibilityState.unexplored) {
      canvas.drawRect(
        size.toRect(),
        Paint()..color = const Color(0xFF000000),
      );
      return;
    }

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

    // Recurso estratégico (se houver)
    if (model.resource != ResourceType.none) {
      final resourceColor = _getResourceColor(model.resource);
      // Brilho de fundo para o recurso
      canvas.drawRect(
        size.toRect(),
        Paint()..color = resourceColor.withValues(alpha: 0.2),
      );

      // Ícone do recurso no canto superior esquerdo
      final iconSize = size.x * 0.25;
      final iconRect = Rect.fromLTWH(3, 3, iconSize, iconSize);
      canvas.drawCircle(
        iconRect.center,
        iconSize / 2,
        Paint()..color = resourceColor,
      );

      // Estrela/símbolo no centro do ícone
      canvas.drawCircle(
        iconRect.center,
        iconSize / 4,
        Paint()..color = Colors.white,
      );
    }

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

    // Destacar células recém-conquistadas
    if (model.justConquered) {
      // Brilho dourado pulsante
      canvas.drawRect(
        size.toRect(),
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.4)
          ..style = PaintingStyle.fill,
      );

      // Borda grossa dourada
      canvas.drawRect(
        size.toRect().deflate(3),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = const Color(0xFFFFB300),
      );
    }

    // Mostrar zona em disputa (múltiplos jogadores com influência)
    if (model.influence.length > 1 && model.b == Building.vazio) {
      final sorted = model.influence.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Borda dupla com cores dos 2 jogadores com mais influência
      if (sorted.length >= 2) {
        final color1 = game.borderColorForOwner(sorted[0].key);
        final color2 = game.borderColorForOwner(sorted[1].key);

        // Borda externa
        canvas.drawRect(
          size.toRect().deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = color1,
        );

        // Borda interna
        canvas.drawRect(
          size.toRect().deflate(5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color2,
        );
      }
    }

    // Fog of War: Overlay para células explored (já vistas mas não atualmente visíveis)
    if (visibility == VisibilityState.explored) {
      canvas.drawRect(
        size.toRect(),
        Paint()..color = const Color(0x99000000), // 60% preto
      );
    }
  }

  Color _getResourceColor(ResourceType resource) {
    switch (resource) {
      case ResourceType.none:
        return Colors.transparent;
      case ResourceType.energyBonus:
        return const Color(0xFFFDD835); // Amarelo brilhante (energia)
      case ResourceType.treasury:
        return const Color(0xFFFFB300); // Dourado (dinheiro)
      case ResourceType.cleanSource:
        return const Color(0xFF66BB6A); // Verde (sustentabilidade)
      case ResourceType.research:
        return const Color(0xFF42A5F5); // Azul (ciência)
      case ResourceType.fertileLand:
        return const Color(0xFF8D6E63); // Marrom (terra fértil)
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final res = game.placeAt(cx, cy);
    game.lastPlaceResult = res;
    super.onTapDown(event);
  }
}
