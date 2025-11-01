// ===== Preview =====
    if (!gameRef.removeMode) {
      // construir: célula vazia → contorno verde se pode pagar, vermelho se não.
      if (model.b == Building.vazio) {
        final selected = gameRef.selecionado ?? Building.solar;
        final canAfford = gameRef.state.orcamento >= gameRef.costOf(selected);
        c.drawRect(
          size.toRect().deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = canAfford ? const Color(0xFF66BB6A) : const Color(0xFFE57373),
        );
      }
    } else {
      // remover: célula ocupada → overlay vermelho suave
      if (model.b != Building.vazio) {
        c.drawRect(
          size.toRect().deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = const Color(0xFFE53935),
        );
        c.drawRect(
          size.toRect(),
          Paint()..color = const Color(0x80E53935), // overlay semi-transparente
        );
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final res = gameRef.placeAt(cx, cy);
    gameRef.lastPlaceResult = res;
    super.onTapDown(event);
  }
}
