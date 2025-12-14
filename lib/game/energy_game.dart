import 'dart:convert';

import 'package:flame/components.dart' show Anchor, Sprite, Vector2;
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/cell.dart';
import 'economy.dart';
import 'state/game_state.dart';
import 'victory_type.dart';
import 'world_events.dart';

enum PlaceResult { ok, semOrcamento, invalido, removido }

class EnergyGame extends FlameGame {
  EnergyGame() {
    state = GameState(size: 10);
    selecionado = Building.solar;
    setLocalPlayer('solo');
  }

  late GameState state;
  Building? selecionado;
  late final Map<Building, Sprite> sprites;

  // Map de resultados por jogador para evitar feedback incorreto em multiplayer
  final Map<String, PlaceResult?> _lastPlaceResults = {};

  bool removeMode = false;

  PlaceResult? get lastPlaceResult => _lastPlaceResults[_localPlayerId];
  set lastPlaceResult(PlaceResult? value) => _lastPlaceResults[_localPlayerId] = value;

  String _localPlayerId = 'solo';
  final Map<String, Color> _ownerColors = {};

  double tileSize = 64.0;
  double reservedTop = 120;
  double reservedBottom = 140;
  Vector2 gridOffset = Vector2.zero();

  double bestClean = 0.0;
  int bestTurn = 999;

  WorldEvent? lastTriggeredEvent;

  static const _stateKey = 'savedGameState';

  double costOf(Building b) {
    switch (b) {
      case Building.solar:
        return 10.0; // Era 8.5 - Aumentado pois gera muita energia
      case Building.eolica:
        return 12.0; // Era 10.0 - Aumentado pois gera mais que solar
      case Building.eficiencia:
        return 8.0; // Era 6.5 - Aumentado pois é muito útil
      case Building.saneamento:
        return 8.0; // Era 7.0 - Ajustado para igualar eficiência
      case Building.vazio:
        return 0.0;
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF212121);

  String get localPlayerId => _localPlayerId;

  void setLocalPlayer(String playerId) {
    _localPlayerId = playerId;
    state.ensurePlayer(playerId);
    _ownerColors.putIfAbsent(
      playerId,
      () => Colors.lightBlueAccent,
    );
  }

  void setOwnerColor(String ownerId, Color color) {
    _ownerColors[ownerId] = color;
  }

  bool hasOwnerColor(String ownerId) => _ownerColors.containsKey(ownerId);

  Color colorForOwner(String? ownerId) {
    if (ownerId == null) {
      return const Color(0xFF424242);
    }
    final base = _ownerColors[ownerId] ?? Colors.grey.shade600;
    return Color.lerp(base, Colors.white, 0.35) ?? base;
  }

  Color borderColorForOwner(String? ownerId) {
    if (ownerId == null) {
      return const Color(0xFF616161);
    }
    return _ownerColors[ownerId] ?? Colors.grey.shade600;
  }

  PlayerState _playerState(String playerId) {
    state.ensurePlayer(playerId);
    return state.playerStates[playerId]!;
  }

  PlayerState get localPlayerState => _playerState(_localPlayerId);

  PlayerState playerStateFor(String playerId) => _playerState(playerId);

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
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
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

  PlaceResult placeAt(int x, int y, {String? actingPlayerId, Building? building}) {
    final playerId = actingPlayerId ?? _localPlayerId;
    final actingState = _playerState(playerId);

    if (_outOfBounds(x, y) || state.acabou()) {
      return lastPlaceResult = PlaceResult.invalido;
    }

    final cell = state.grid[x][y];

    if (removeMode) {
      if ((cell.ownerId != null && cell.ownerId != playerId) ||
          cell.b == Building.vazio) {
        return lastPlaceResult = PlaceResult.invalido;
      }

      final refund = costOf(cell.b) * 0.5;
      final refundOwner = cell.ownerId ?? playerId;
      _playerState(refundOwner).orcamento += refund;
      cell
        ..b = Building.vazio
        ..powered = false;
      lastPlaceResult = PlaceResult.removido;
      _recomputeMetrics();
      saveGame();
      return PlaceResult.removido;
    }

    final buildingToPlace = building ?? selecionado ?? Building.solar;
    if (cell.b != Building.vazio) {
      return lastPlaceResult = PlaceResult.invalido;
    }

    if (!canControlCell(playerId, x, y)) {
      return lastPlaceResult = PlaceResult.invalido;
    }

    final custo = costOf(buildingToPlace);
    if (actingState.orcamento < custo) {
      return lastPlaceResult = PlaceResult.semOrcamento;
    }

    actingState.orcamento -= custo;
    cell
      ..b = buildingToPlace
      ..powered = true
      ..ownerId = playerId;
    lastPlaceResult = PlaceResult.ok;

    _recomputeMetrics();
    saveGame();
    return PlaceResult.ok;
  }

  void endTurn() {
    if (state.acabou()) return;
    state.turno += 1;

    // Processar eventos globais
    state.worldState.tickEvents();
    _tryTriggerRandomEvent();
    _applyEventEffects();

    // Calcular economia energética
    _calculateEnergyEconomy();

    for (final playerId in state.registeredPlayers) {
      final playerState = _playerState(playerId);
      final efficiencyBonus =
          _countOwned(playerId, Building.eficiencia) * 0.6; // Era 0.5

      // Orçamento base + bônus eficiência + impacto econômico
      playerState.orcamento += 6 + efficiencyBonus + playerState.economy.economicImpact; // Base era 4, agora 6
    }

    _recomputeMetrics();
    _expandTerritories(); // Nova função de expansão
    _updateWorldClimate();
    _captureProgress();
    saveGame();
  }

  void _recomputeMetrics() {
    final totalCells = (state.size * state.size).toDouble();
    final global = _MetricAccumulator()..territory = state.size * state.size;
    final perPlayer = <String, _MetricAccumulator>{};

    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        final owner = cell.ownerId;
        if (owner != null) {
          state.ensurePlayer(owner);
          perPlayer.putIfAbsent(owner, _MetricAccumulator.new).territory++;
        }

        if (cell.b != Building.vazio) {
          cell.powered = true;
          global.record(cell.b);
          if (owner != null) {
            perPlayer.putIfAbsent(owner, _MetricAccumulator.new).record(cell.b);
          }
        } else {
          cell.powered = false;
        }
      }
    }

    for (final entry in state.playerStates.entries) {
      final playerId = entry.key;
      final player = entry.value;
      final acc = perPlayer[playerId];
      if (acc == null || acc.territory == 0) {
        player.metrics.reset();
        continue;
      }
      final territory = acc.territory.toDouble();
      final built = acc.built.toDouble();

      // Aplicar bônus de eventos em energia limpa
      var effectiveClean = acc.clean.toDouble();
      if (state.worldState.hasActiveEvent(EventType.tempestadeSolar)) {
        // Contar painéis solares com bônus
        final solarCount = _countOwnedByType(playerId, Building.solar);
        effectiveClean += solarCount * 0.5; // +50% bonus
      }
      if (state.worldState.hasActiveEvent(EventType.ventosFavoraveis)) {
        // Contar turbinas eólicas com bônus
        final windCount = _countOwnedByType(playerId, Building.eolica);
        effectiveClean += windCount * 0.4; // +40% bonus
      }

      final effectiveCleanRatio = built == 0 ? 0.0 : (effectiveClean / built).clamp(0, 1).toDouble();

      var tarifa = _computeTarifa(acc.clean, built, acc.efficiency);
      var saude = (0.40 + acc.sanitation / territory * 0.60).clamp(0, 1).toDouble();
      var clima = (0.45 + effectiveClean / territory * 0.55).clamp(0, 1).toDouble();

      // Aplicar efeitos de eventos
      if (state.worldState.hasActiveEvent(EventType.criseTarifaria)) {
        tarifa *= 1.2; // Aumento de 20%
      }
      if (state.worldState.hasActiveEvent(EventType.surtoSaude)) {
        saude = (saude + 0.10).clamp(0, 1);
      }
      if (state.worldState.hasActiveEvent(EventType.ondaDeCalor)) {
        clima = (clima - 0.15).clamp(0, 1);
      }

      player.metrics
        ..acessoEnergia = (built / territory).clamp(0, 1).toDouble()
        ..limpa = effectiveCleanRatio
        ..tarifa = tarifa
        ..saude = saude
        ..educacao =
            (0.35 + acc.efficiency / territory * 0.55).clamp(0, 1).toDouble()
        ..desigualdade =
            (0.60 - (acc.sanitation + acc.efficiency) / territory * 0.45)
                .clamp(0, 1)
                .toDouble()
        ..clima = clima;
    }

    final builtGlobal = global.built.toDouble();
    final cleanRatioGlobal =
        builtGlobal == 0 ? 0 : global.clean / builtGlobal;

    var tarifaGlobal = _computeTarifa(global.clean, builtGlobal, global.efficiency);
    var saudeGlobal = (0.40 + global.sanitation / totalCells * 0.60).clamp(0, 1).toDouble();
    var climaGlobal = (0.45 + global.clean / totalCells * 0.55).clamp(0, 1).toDouble();

    // Aplicar efeitos de eventos globais
    if (state.worldState.hasActiveEvent(EventType.criseTarifaria)) {
      tarifaGlobal *= 1.2;
    }
    if (state.worldState.hasActiveEvent(EventType.surtoSaude)) {
      saudeGlobal = (saudeGlobal + 0.10).clamp(0, 1);
    }
    if (state.worldState.hasActiveEvent(EventType.ondaDeCalor)) {
      climaGlobal = (climaGlobal - 0.15).clamp(0, 1);
    }

    state.metrics
      ..acessoEnergia = (builtGlobal / totalCells).clamp(0, 1).toDouble()
      ..limpa = cleanRatioGlobal.clamp(0, 1).toDouble()
      ..tarifa = tarifaGlobal
      ..saude = saudeGlobal
      ..educacao =
          (0.35 + global.efficiency / totalCells * 0.55).clamp(0, 1).toDouble()
      ..desigualdade =
          (0.60 - (global.sanitation + global.efficiency) / totalCells * 0.45)
              .clamp(0, 1)
              .toDouble()
      ..clima = climaGlobal;

    // Atualizar influência dos jogadores
    for (final entry in state.playerStates.entries) {
      final playerId = entry.key;
      final player = entry.value;
      final acc = perPlayer[playerId] ?? _MetricAccumulator();

      // Influência baseada em construções
      player.influenciaEnergia = (acc.clean * 2.0).toDouble();
      player.influenciaSocial = ((acc.efficiency + acc.sanitation) * 1.5).toDouble();
    }
  }

  void _expandTerritories() {
    // Calcular influência de cada jogador em células vazias adjacentes
    final influenceMap = <String, Map<String, double>>{};

    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];

        // Para cada célula com construção, propagar influência
        if (cell.b != Building.vazio && cell.ownerId != null) {
          final playerId = cell.ownerId!;
          final player = _playerState(playerId);
          final influenceValue = _getBuildingInfluence(cell.b);

          _propagateInfluence(x, y, playerId, influenceValue * player.influenciaTotal, influenceMap);
        }
      }
    }

    // Aplicar influência e resolver disputas
    _resolveTerritoryConflicts(influenceMap);
  }

  double _getBuildingInfluence(Building b) {
    switch (b) {
      case Building.solar:
      case Building.eolica:
        return 1.5; // Energia limpa tem mais alcance
      case Building.eficiencia:
      case Building.saneamento:
        return 1.2;
      case Building.vazio:
        return 0.0;
    }
  }

  void _propagateInfluence(
    int centerX,
    int centerY,
    String playerId,
    double baseInfluence,
    Map<String, Map<String, double>> influenceMap,
  ) {
    const radius = 2; // Alcance de influência

    for (var dx = -radius; dx <= radius; dx++) {
      for (var dy = -radius; dy <= radius; dy++) {
        if (dx == 0 && dy == 0) continue;

        final x = centerX + dx;
        final y = centerY + dy;

        if (_outOfBounds(x, y)) continue;

        final distance = (dx.abs() + dy.abs()).toDouble();
        final influence = baseInfluence / (distance + 1);

        final key = '$x,$y';
        influenceMap.putIfAbsent(key, () => {});
        influenceMap[key]![playerId] = (influenceMap[key]![playerId] ?? 0) + influence;
      }
    }
  }

  void _resolveTerritoryConflicts(Map<String, Map<String, double>> influenceMap) {
    // Primeiro, limpar todas as marcas de conquista antiga
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        state.grid[x][y].justConquered = false;
      }
    }

    for (final entry in influenceMap.entries) {
      final coords = entry.key.split(',');
      final x = int.parse(coords[0]);
      final y = int.parse(coords[1]);
      final cell = state.grid[x][y];

      // Atualizar mapa de influência na célula
      cell.influence = Map.from(entry.value);

      // Só pode tomar território se célula estiver vazia
      if (cell.b == Building.vazio && cell.ownerId == null) {
        // Encontrar jogador com maior influência
        String? dominantPlayer;
        double maxInfluence = 3.0; // Threshold mínimo

        for (final playerEntry in entry.value.entries) {
          if (playerEntry.value > maxInfluence) {
            maxInfluence = playerEntry.value;
            dominantPlayer = playerEntry.key;
          }
        }

        // Atribuir território ao jogador dominante
        if (dominantPlayer != null) {
          cell.ownerId = dominantPlayer;
          cell.justConquered = true; // Marcar como recém-conquistada
        }
      }
    }
  }

  double _computeTarifa(
    int cleanSources,
    double builtCells,
    int efficiencyCount,
  ) {
    if (builtCells == 0) return 1.0;
    final dirtySources = builtCells - cleanSources;
    final base = 1.0 + dirtySources / builtCells * 0.40;
    final discounts = (efficiencyCount * 0.08).clamp(0, 0.45);
    return (base * (1 - discounts)).clamp(0.55, 1.35);
  }

  int _countOwned(String playerId, Building b) {
    int c = 0;
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        if (cell.ownerId == playerId && cell.b == b) {
          c++;
        }
      }
    }
    return c;
  }

  int _countOwnedByType(String playerId, Building b) {
    return _countOwned(playerId, b);
  }


  bool _outOfBounds(int x, int y) =>
      x < 0 || y < 0 || x >= state.size || y >= state.size;

  bool playerHasAnyCell(String playerId) {
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        if (state.grid[x][y].ownerId == playerId) {
          return true;
        }
      }
    }
    return false;
  }

  @protected
  bool canControlCell(String playerId, int x, int y) {
    final cell = state.grid[x][y];
    if (cell.ownerId != null && cell.ownerId != playerId) {
      return false;
    }

    if (cell.ownerId == playerId) {
      return true;
    }

    if (!playerHasAnyCell(playerId)) {
      return true;
    }

    return _hasAdjacentOwnedCell(playerId, x, y);
  }

  bool _hasAdjacentOwnedCell(String playerId, int x, int y) {
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];

    for (final dir in dirs) {
      final nx = x + dir[0];
      final ny = y + dir[1];
      if (_outOfBounds(nx, ny)) continue;
      if (state.grid[nx][ny].ownerId == playerId) {
        return true;
      }
    }
    return false;
  }

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

  @protected
  bool get shouldSaveLocally => true;

  Future<void> saveGame() async {
    if (!shouldSaveLocally) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_stateKey, jsonEncode(state.toJson()));
  }

  Future<void> loadGame() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_stateKey);
    Map<String, dynamic>? data;

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
          state = GameState.fromJson(decoded);
        } else {
          state = GameState(size: state.size);
        }
      } catch (_) {
        state = GameState(size: state.size);
      }
    } else {
      state = GameState(size: state.size);
    }

    final hasPlayers = data is Map<String, dynamic> && data['players'] is Map;
    final legacyBudget =
        data is Map<String, dynamic> ? (data['orcamento'] ?? 100).toDouble() : 100.0;

    final localState = _playerState(_localPlayerId);
    if (!hasPlayers) {
      localState.orcamento = legacyBudget;
    }

    _recomputeMetrics();
    selecionado ??= Building.solar;
  }

  // ===== Sistema Econômico (Fase 15) =====

  void _calculateEnergyEconomy() {
    for (final playerId in state.registeredPlayers) {
      final playerState = _playerState(playerId);
      final territory = state.getTerritorySize(playerId);

      // Contar construções
      final solarCount = _countOwned(playerId, Building.solar);
      final windCount = _countOwned(playerId, Building.eolica);
      final efficiencyCount = _countOwned(playerId, Building.eficiencia);

      // Multiplicadores de eventos
      var solarMultiplier = 1.0;
      var windMultiplier = 1.0;

      if (state.worldState.hasActiveEvent(EventType.tempestadeSolar)) {
        solarMultiplier = 1.5; // +50%
      }
      if (state.worldState.hasActiveEvent(EventType.ventosFavoraveis)) {
        windMultiplier = 1.4; // +40%
      }

      // Calcular geração e consumo
      final generation = EnergyEconomy.calculateGeneration(
        solarCount,
        windCount,
        solarMultiplier: solarMultiplier,
        windMultiplier: windMultiplier,
      );
      final consumption = EnergyEconomy.calculateConsumption(
        territory,
        efficiencyCount,
      );

      // Atualizar economia do jogador
      playerState.economy.update(
        generation: generation,
        consumption: consumption,
        tariff: playerState.metrics.tarifa,
      );
    }
  }

  // ===== Sistema de Eventos Globais (Fase 16) =====

  void _tryTriggerRandomEvent() {
    // 20% de chance de evento a cada turno (após turno 3) - Reduzido de 25%
    if (state.turno <= 3) return;

    final random = DateTime.now().millisecondsSinceEpoch % 100;
    if (random < 20) {
      final eventIndex = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % WorldEvent.all.length;
      final event = WorldEvent.all[eventIndex];

      state.worldState.addEvent(event);
      lastTriggeredEvent = event;
    } else {
      lastTriggeredEvent = null;
    }
  }

  void _applyEventEffects() {
    for (final activeEvent in state.worldState.activeEvents) {
      final event = activeEvent.event;

      switch (event.type) {
        case EventType.investimentoPublico:
          // Dar bônus de orçamento para todos os jogadores
          for (final playerId in state.registeredPlayers) {
            _playerState(playerId).orcamento += 15;
          }
          break;

        case EventType.surtoSaude:
          // Bonus de saúde será aplicado em _recomputeMetrics
          break;

        case EventType.tempestadeSolar:
        case EventType.ventosFavoraveis:
        case EventType.criseTarifaria:
        case EventType.ondaDeCalor:
          // Efeitos aplicados durante cálculo de métricas
          break;
      }
    }
  }

  void _updateWorldClimate() {
    // Calcular poluição baseada em energia não-limpa
    final totalCells = state.size * state.size;
    var dirtyCells = 0;

    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        if (cell.b != Building.vazio &&
            cell.b != Building.solar &&
            cell.b != Building.eolica) {
          dirtyCells++;
        }
      }
    }

    // Atualizar poluição atmosférica (0..1)
    state.worldState.poluicaoAtmosferica =
        (dirtyCells / totalCells * 0.7 + state.worldState.poluicaoAtmosferica * 0.3)
            .clamp(0, 1)
            .toDouble();

    // Atualizar temperatura global baseada em limpa
    final targetTemp = 1.0 + (1.0 - state.metrics.limpa) * 0.5;
    state.worldState.temperaturaGlobal =
        (targetTemp * 0.2 + state.worldState.temperaturaGlobal * 0.8)
            .clamp(0.5, 1.5)
            .toDouble();
  }

  // ===== Sistema de Vitórias (Fase 17) =====

  /// Calcula as pontuações finais de todos os jogadores
  List<PlayerScore> calculateFinalScores() {
    final scores = <PlayerScore>[];

    for (final playerId in state.registeredPlayers) {
      final playerState = _playerState(playerId);
      final metrics = playerState.metrics;
      final territory = state.getTerritorySize(playerId);

      // Calcular pontuações
      final sustentabilidade = (metrics.acessoEnergia + metrics.limpa) / 2.0;
      final economia = playerState.orcamento;
      final ciencia = (metrics.educacao + (1.0 - metrics.tarifa)) / 2.0;

      final playerColor = _ownerColors[playerId];
      final colorHex = playerColor != null
          ? '${(playerColor.r * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(playerColor.g * 255).round().toRadixString(16).padLeft(2, '0')}'
              '${(playerColor.b * 255).round().toRadixString(16).padLeft(2, '0')}'
          : 'FFFFFF';

      scores.add(PlayerScore(
        playerId: playerId,
        color: colorHex,
        sustentabilidade: sustentabilidade,
        economia: economia,
        ciencia: ciencia,
        territorio: territory,
      ));
    }

    // Determinar vitórias
    _assignVictories(scores);

    return scores;
  }

  void _assignVictories(List<PlayerScore> scores) {
    if (scores.isEmpty) return;

    // Vitória Sustentável
    final bestSustentavel = scores.reduce((a, b) =>
        a.sustentabilidade > b.sustentabilidade ? a : b);
    bestSustentavel.victories.add(VictoryType.sustentavel);

    // Vitória Econômica
    final bestEconomica = scores.reduce((a, b) =>
        a.economia > b.economia ? a : b);
    bestEconomica.victories.add(VictoryType.economica);

    // Vitória Científica
    final bestCientifica = scores.reduce((a, b) =>
        a.ciencia > b.ciencia ? a : b);
    bestCientifica.victories.add(VictoryType.cientifica);

    // Vitória Territorial
    final bestTerritorial = scores.reduce((a, b) =>
        a.territorio > b.territorio ? a : b);
    bestTerritorial.victories.add(VictoryType.territorial);

    // Vitória Coletiva (clima global >= 0.7)
    if (state.metrics.clima >= 0.7) {
      for (final score in scores) {
        score.victories.add(VictoryType.coletiva);
      }
    }
  }

  /// Verifica se há vitória coletiva
  bool hasCollectiveVictory() {
    return state.metrics.clima >= 0.7;
  }
}

class _MetricAccumulator {
  int territory = 0;
  int built = 0;
  int clean = 0;
  int efficiency = 0;
  int sanitation = 0;

  void record(Building building) {
    built++;
    switch (building) {
      case Building.solar:
      case Building.eolica:
        clean++;
        break;
      case Building.eficiencia:
        efficiency++;
        break;
      case Building.saneamento:
        sanitation++;
        break;
      case Building.vazio:
        break;
    }
  }
}
