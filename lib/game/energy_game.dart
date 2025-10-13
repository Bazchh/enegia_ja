import 'dart:convert';

import 'package:flame/components.dart' show Anchor, Sprite, Vector2;
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/cell.dart';
import 'state/game_state.dart';

enum PlaceResult { ok, semOrcamento, invalido, removido }

class EnergyGame extends FlameGame {
  EnergyGame() {
    state = GameState(size: 10);
    selecionado = Building.solar;
  }

  late GameState state;
  Building? selecionado;
  late final Map<Building, Sprite> sprites;
  PlaceResult? lastPlaceResult;

  bool removeMode = false;

  double tileSize = 64.0;
  double reservedTop = 120;
  double reservedBottom = 140;
  Vector2 gridOffset = Vector2.zero();

  double bestClean = 0.0;
  int bestTurn = 999;

  static const _stateKey = 'savedGameState';

  double costOf(Building b) {
    switch (b) {
      case Building.solar:
        return 9.0;
      case Building.eolica:
        return 11.0;
      case Building.eficiencia:
        return 7.0;
      case Building.saneamento:
        return 7.5;
      case Building.vazio:
        return 0.0;
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF212121);

  @override
  Future<void> onLoad() async {
    await _loadProgress();
    await loadGame();

    const iconPaths = {
      Building.solar: 'icons/icon_solar.png',
      Building.eolica: 'icons/icon_wind.png',
      Building.eficiencia: 'icons/icon_efficiency.png',
      Building.saneamento: 'icons/icon_sanitation.png',
    };

    await images.loadAll(iconPaths.values.toList());
    sprites = {
      for (final entry in iconPaths.entries)
        entry.key: Sprite(images.fromCache(entry.value)),
    };

    await Flame.device.fullScreen();
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    _recomputeLayout();

    if (world.children.whereType<Cell>().isEmpty) {
      for (var x = 0; x < state.size; x++) {
        for (var y = 0; y < state.size; y++) {
          await world.add(Cell(x, y));
        }
      }
    }
    _applyLayoutToCells();
    _recomputeMetrics();
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _recomputeLayout();
    _applyLayoutToCells();
  }

  void _recomputeLayout() {
    if (size.x <= 0 || size.y <= 0) return;

    final usableHeight =
        (size.y - reservedTop - reservedBottom).clamp(100, size.y);
    final maxTileX = size.x / state.size;
    final maxTileY = usableHeight / state.size;
    tileSize = maxTileX < maxTileY ? maxTileX : maxTileY;
    if (tileSize < 20) tileSize = 20;

    final gridPxW = tileSize * state.size;
    final gridPxH = tileSize * state.size;
    final padX = ((size.x - gridPxW) / 2).clamp(0, size.x).toDouble();
    final extraY =
        ((usableHeight - gridPxH) / 2).clamp(0, usableHeight).toDouble();
    final padY = reservedTop + extraY;
    gridOffset = Vector2(padX, padY);
  }

  void _applyLayoutToCells() {
    for (final cell in world.children.whereType<Cell>()) {
      cell.size = Vector2.all(tileSize);
      cell.position =
          gridOffset + Vector2(cell.cx * tileSize, cell.cy * tileSize);
    }
  }

  void restart() {
    state.reset();
    selecionado ??= Building.solar;
    removeMode = false;
    lastPlaceResult = null;
    _recomputeMetrics();
    saveGame();
  }

  PlaceResult placeAt(int x, int y) {
    if (_outOfBounds(x, y) || state.acabou()) {
      return lastPlaceResult = PlaceResult.invalido;
    }

    final cell = state.grid[x][y];

    if (removeMode) {
      if (cell.b == Building.vazio) {
        return lastPlaceResult = PlaceResult.invalido;
      }
      final refund = costOf(cell.b) * 0.5;
      state.orcamento += refund;
      cell
        ..b = Building.vazio
        ..powered = false;
      lastPlaceResult = PlaceResult.removido;
      _recomputeMetrics();
      saveGame();
      return PlaceResult.removido;
    }

    final building = selecionado ?? Building.solar;
    if (cell.b != Building.vazio) {
      return lastPlaceResult = PlaceResult.invalido;
    }

    final custo = costOf(building);
    if (state.orcamento < custo) {
      return lastPlaceResult = PlaceResult.semOrcamento;
    }

    state.orcamento -= custo;
    cell
      ..b = building
      ..powered = true;
    lastPlaceResult = PlaceResult.ok;

    _recomputeMetrics();
    saveGame();
    return PlaceResult.ok;
  }

  void endTurn() {
    if (state.acabou()) return;
    state.turno += 1;

    final efficiencyBonus = _count(Building.eficiencia) * 0.5;
    state.orcamento += 4 + efficiencyBonus;

    _recomputeMetrics();
    _captureProgress();
    saveGame();
  }

  void _recomputeMetrics() {
    final totalCells = (state.size * state.size).toDouble();
    int energized = 0;
    int cleanSources = 0;
    int efficiencyCount = 0;
    int sanitationCount = 0;

    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        final building = cell.b;
        if (building != Building.vazio) {
          energized++;
          cell.powered = true;
        } else {
          cell.powered = false;
        }

        switch (building) {
          case Building.solar:
          case Building.eolica:
            cleanSources++;
            break;
          case Building.eficiencia:
            efficiencyCount++;
            break;
          case Building.saneamento:
            sanitationCount++;
            break;
          case Building.vazio:
            break;
        }
      }
    }

    final builtCells = energized.toDouble();
    final cleanRatio = builtCells == 0 ? 0 : cleanSources / builtCells;

    state.metrics
      ..acessoEnergia = (builtCells / totalCells).clamp(0, 1).toDouble()
      ..limpa = cleanRatio.clamp(0, 1).toDouble()
      ..tarifa = _computeTarifa(cleanSources, builtCells, efficiencyCount)
      ..saude = (0.45 + sanitationCount / totalCells * 0.55).clamp(0, 1).toDouble()
      ..educacao = (0.40 + efficiencyCount / totalCells * 0.45).clamp(0, 1).toDouble()
      ..desigualdade =
          (0.55 - (sanitationCount + efficiencyCount) / totalCells * 0.35)
              .clamp(0, 1).toDouble()
      ..clima = (0.5 + cleanSources / totalCells * 0.5).clamp(0, 1).toDouble();
  }

  double _computeTarifa(
    int cleanSources,
    double builtCells,
    int efficiencyCount,
  ) {
    if (builtCells == 0) return 1.0;
    final dirtySources = builtCells - cleanSources;
    final base = 1.05 + dirtySources / builtCells * 0.35;
    final discounts = (efficiencyCount * 0.06).clamp(0, 0.4);
    return (base * (1 - discounts)).clamp(0.6, 1.4);
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

  bool _outOfBounds(int x, int y) =>
      x < 0 || y < 0 || x >= state.size || y >= state.size;

  Future<void> _loadProgress() async {
    final sp = await SharedPreferences.getInstance();
    bestClean = sp.getDouble('bestClean') ?? 0.0;
    bestTurn = sp.getInt('bestTurn') ?? 999;
  }

  Future<void> _saveProgress() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('bestClean', bestClean);
    await sp.setInt('bestTurn', bestTurn);
  }

  void _captureProgress() {
    final clean = state.metrics.limpa;
    if (clean > bestClean) {
      bestClean = clean;
      _saveProgress();
    }
    if (state.venceu() && state.turno < bestTurn) {
      bestTurn = state.turno;
      _saveProgress();
    }
  }

  Future<void> saveGame() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_stateKey, jsonEncode(state.toJson()));
  }

  Future<void> loadGame() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_stateKey);
    if (raw == null) {
      _recomputeMetrics();
      selecionado ??= Building.solar;
      return;
    }
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        state = GameState.fromJson(data);
      }
    } catch (_) {
      state = GameState(size: 10);
    }
    _recomputeMetrics();
    selecionado ??= Building.solar;
  }
}
