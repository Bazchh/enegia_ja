import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart' show Anchor, Sprite, Vector2;
import 'package:flutter/material.dart';
import 'components/cell.dart';
import 'state/game_state.dart';

enum PlaceResult { ok, semOrcamento, ocupado, fimDeJogo }

class EnergyGame extends FlameGame {
  final state = GameState(size: 10);
  Building selecionado = Building.solar;
  late final Map<Building, Sprite> sprites;
  PlaceResult? lastPlaceResult;

  // modo remover
  bool removeMode = false;
  void toggleRemoveMode() => removeMode = !removeMode;

  // responsividade
  double tileSize = 64.0;
  double reservedTop = 120;     // espaço do card de métricas
  double reservedBottom = 140;  // espaço dos botões
  Vector2 gridOffset = Vector2.zero();

  // custos
  double costOf(Building b) {
    switch (b) {
      case Building.solar: return 8.0;
      case Building.eolica: return 10.0;
      case Building.eficiencia: return 6.0;
      case Building.saneamento: return 6.0;
      case Building.vazio: return 0.0;
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF212121);

  @override
  Future<void> onLoad() async {
    // OBS: caminhos relativos ao /assets/
    await images.loadAll([
      'icons/icon_solar.png',
      'icons/icon_wind.png',
      'icons/icon_efficiency.png',
      'icons/icon_sanitation.png',
    ]);
    sprites = {
      Building.solar: Sprite(images.fromCache('icons/icon_solar.png')),
      Building.eolica: Sprite(images.fromCache('icons/icon_wind.png')),
      Building.eficiencia: Sprite(images.fromCache('icons/icon_efficiency.png')),
      Building.saneamento: Sprite(images.fromCache('icons/icon_sanitation.png')),
    };

    await Flame.device.fullScreen();
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    _recomputeLayout();

    // grid
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        await world.add(Cell(x, y));
      }
    }
    _applyLayoutToCells();
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _recomputeLayout();
    _applyLayoutToCells();
  }

  void _recomputeLayout() {
    if (size.x <= 0 || size.y <= 0) return;

    final usableHeight = (size.y - reservedTop - reservedBottom).clamp(100, size.y);
    final maxTileX = size.x / state.size;
    final maxTileY = usableHeight / state.size;
    tileSize = maxTileX < maxTileY ? maxTileX : maxTileY;
    if (tileSize < 20) tileSize = 20;

    final gridPxW = tileSize * state.size;
    final gridPxH = tileSize * state.size;
    final padX = ((size.x - gridPxW) / 2).clamp(0, size.x).toDouble();
    final extraY = ((usableHeight - gridPxH) / 2).clamp(0, usableHeight).toDouble();
    final padY = reservedTop + extraY;
    gridOffset = Vector2(padX, padY);
  }

  void _applyLayoutToCells() {
    for (final cell in world.children.whereType<Cell>()) {
      cell.size = Vector2.all(tileSize);
      cell.position = gridOffset + Vector2(cell.cx * tileSize, cell.cy * tileSize);
    }
  }

  void restart() => state.reset();

  void tickTurno() {
    final total = state.size * state.size;
    int powered = 0, limpas = 0;
    double custoTotal = 0, co2 = 0;

    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        if (cell.b != Building.vazio) cell.powered = true;
        if (cell.powered) powered++;

        switch (cell.b) {
          case Building.solar:   limpas++; custoTotal += 1.2; co2 += 0.10; break;
          case Building.eolica:  limpas++; custoTotal += 1.0; co2 += 0.05; break;
          case Building.eficiencia: break;
          case Building.saneamento: break;
          case Building.vazio: break;
        }
      }
    }

    final eficienciaCount = _count(Building.eficiencia);
    final saneamentoCount = _count(Building.saneamento);

    state.metrics.acessoEnergia = powered / total;
    state.metrics.limpa = limpas / (powered == 0 ? 1 : powered);
    state.metrics.saude = (0.5 + saneamentoCount / total).clamp(0, 1);
    state.metrics.educacao = (state.metrics.educacao + 0.01).clamp(0, 1);
    state.metrics.desigualdade = (state.metrics.desigualdade - 0.01).clamp(0, 1);
    state.metrics.clima = (1.0 - co2 / total).clamp(0, 1);

    final red = (0.2 * eficienciaCount).clamp(0, 0.5);
    state.metrics.tarifa =
        (custoTotal / (limpas == 0 ? 1 : limpas) * (1 - red)).clamp(0.6, 1.4);

    state.turno++;
  }

  int _count(Building b) {
    int c = 0;
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        if (state.grid[x][y].b == b) c++;
      }
    }
    return c;
  }

  PlaceResult placeAt(int x, int y) {
    if (state.acabou()) return PlaceResult.fimDeJogo;

    final cell = state.grid[x][y];
    if (cell.b != Building.vazio) return PlaceResult.ocupado;

    final custo = costOf(selecionado);
    if (state.orcamento < custo) return PlaceResult.semOrcamento;

    cell.b = selecionado;
    cell.powered = true;
    state.orcamento -= custo;

    tickTurno();
    return PlaceResult.ok;
  }

  // remover: devolve 50% do custo
  bool removeAt(int x, int y) {
    final cell = state.grid[x][y];
    if (cell.b == Building.vazio) return false;
    final refund = costOf(cell.b) * 0.5;
    state.orcamento += refund;
    cell.b = Building.vazio;
    cell.powered = false;
    tickTurno();
    return true;
  }
}
