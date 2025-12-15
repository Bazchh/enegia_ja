import 'dart:convert';

import 'package:flame/components.dart' show Anchor, Sprite, Vector2;
import 'package:flame/events.dart';
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

class EnergyGame extends FlameGame with PanDetector {
  EnergyGame({int gridSize = 40}) { // Grid grande para exploração
    state = GameState(size: gridSize);
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

  // Fog of War: Mapa de visibilidade por jogador
  final Map<String, List<List<VisibilityState>>> _visibility = {};
  static const int _visionRadius = 2; // Raio de visão ao redor de territórios

  double tileSize = 64.0;
  double reservedTop = 120;
  double reservedBottom = 140;
  Vector2 gridOffset = Vector2.zero();
  final Map<String, (int, int)> _playerSpawns = {};
  bool _cameraCentered = false;

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

  @override
  bool get debugMode => false;

  String get localPlayerId => _localPlayerId;

  void setLocalPlayer(String playerId) {
    _localPlayerId = playerId;
    state.ensurePlayer(playerId);
    _ownerColors.putIfAbsent(
      playerId,
      () => Colors.lightBlueAccent,
    );
  }

  /// Inicializa spawns aleatórios para todos os jogadores registrados
  void initializePlayerSpawns() {
    final playerIds = state.registeredPlayers.toList();
    if (playerIds.isEmpty) return;

    final spawnPositions = _generateSpawnPositions(playerIds.length);

    for (int i = 0; i < playerIds.length && i < spawnPositions.length; i++) {
      final playerId = playerIds[i];
      final spawn = spawnPositions[i];

      // Dar território inicial (3x3 ao redor do spawn)
      _claimInitialTerritory(playerId, spawn.$1, spawn.$2);
      recordPlayerSpawn(playerId, spawn.$1, spawn.$2, centerIfLocal: false);
    }
  }

  /// Centraliza a câmera em uma célula específica
  void _centerCameraOnCell(int x, int y) {
    final cellCenterX = gridOffset.x + x * tileSize + tileSize / 2;
    final cellCenterY = gridOffset.y + y * tileSize + tileSize / 2;

    camera.viewfinder.position = Vector2(cellCenterX, cellCenterY);
  }

  /// Registra o ponto de spawn de um jogador e, opcionalmente, centraliza a câmera se for o jogador local.
  void recordPlayerSpawn(String playerId, int x, int y, {bool centerIfLocal = false}) {
    _playerSpawns[playerId] = (x, y);

    if (centerIfLocal && playerId == _localPlayerId) {
      _centerCameraOnCell(x, y);
      _cameraCentered = true;
    }
  }

  /// Solicita recentralizar a câmera; se recenterNow for true, tenta imediatamente.
  void requestCameraRecenter({bool recenterNow = false}) {
    _cameraCentered = false;
    if (recenterNow) {
      _centerCameraOnLocalSpawnIfNeeded();
    }
  }

  /// Gera posições de spawn com distância mínima entre elas
  List<(int, int)> _generateSpawnPositions(int count) {
    final positions = <(int, int)>[];
    final minDistance = (state.size * 0.3).toInt(); // 30% do tamanho do mapa
    final random = DateTime.now().millisecondsSinceEpoch;
    var attempts = 0;
    const maxAttempts = 100;

    while (positions.length < count && attempts < maxAttempts) {
      attempts++;

      // Gerar posição aleatória
      final x = (random * (attempts + 1) * 7) % state.size;
      final y = (random * (attempts + 1) * 13) % state.size;

      // Verificar se está longe o suficiente de outros spawns
      var tooClose = false;
      for (final existing in positions) {
        final distance = _calculateDistance(x, y, existing.$1, existing.$2);
        if (distance < minDistance) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        positions.add((x, y));
      }
    }

    // Se não conseguiu gerar todos, usar posições nos cantos
    if (positions.length < count) {
      final corners = [
        (2, 2), // Canto superior esquerdo
        (state.size - 3, 2), // Canto superior direito
        (2, state.size - 3), // Canto inferior esquerdo
        (state.size - 3, state.size - 3), // Canto inferior direito
        (state.size ~/ 2, 2), // Meio superior
        (state.size ~/ 2, state.size - 3), // Meio inferior
      ];

      for (final corner in corners) {
        if (positions.length >= count) break;
        if (!positions.contains(corner)) {
          positions.add(corner);
        }
      }
    }

    return positions;
  }

  /// Calcula distância entre duas posições (Manhattan distance)
  double _calculateDistance(int x1, int y1, int x2, int y2) {
    return ((x1 - x2).abs() + (y1 - y2).abs()).toDouble();
  }

  /// Dá território inicial ao redor do spawn
  void _claimInitialTerritory(String playerId, int centerX, int centerY) {
    // Dar 3x3 de território inicial
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final x = centerX + dx;
        final y = centerY + dy;

        if (!_outOfBounds(x, y)) {
          state.grid[x][y].ownerId = playerId;
        }
      }
    }
  }

  /// Gera pontos de recurso estratégicos aleatoriamente no mapa
  void generateStrategicResources() {
    final resourceTypes = [
      ResourceType.energyBonus,
      ResourceType.treasury,
      ResourceType.cleanSource,
      ResourceType.research,
      ResourceType.fertileLand,
    ];

    // Gerar ~3% do mapa como recursos (para 40x40 = 48 recursos)
    final resourceCount = (state.size * state.size * 0.03).toInt();
    final random = DateTime.now().millisecondsSinceEpoch;
    var placed = 0;
    var attempts = 0;
    const maxAttempts = 1000;

    while (placed < resourceCount && attempts < maxAttempts) {
      attempts++;

      // Posição aleatória
      final x = (random * (attempts + 1) * 17) % state.size;
      final y = (random * (attempts + 1) * 23) % state.size;

      final cell = state.grid[x][y];

      // Não colocar recurso em célula que já tem recurso ou building
      if (cell.resource != ResourceType.none || cell.b != Building.vazio) {
        continue;
      }

      // Distribuir recursos uniformemente
      final resourceType = resourceTypes[placed % resourceTypes.length];
      cell.resource = resourceType;
      placed++;
    }
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
    _centerCameraOnLocalSpawnIfNeeded();
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

    // Para mapas grandes, usar tile size fixo ao invés de tentar caber tudo
    if (state.size > 12) {
      tileSize = 50.0; // Tamanho fixo para mapas grandes
    } else {
      final maxTileX = size.x / state.size;
      final maxTileY = usableHeight / state.size;
      tileSize = maxTileX < maxTileY ? maxTileX : maxTileY;
      if (tileSize < 20) tileSize = 20;
    }

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
    _cameraCentered = false;
    _playerSpawns.clear();

    // Reinicializar spawns
    initializePlayerSpawns();

    // Gerar recursos estratégicos no mapa
    generateStrategicResources();

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

    var custo = costOf(buildingToPlace);

    // Aplicar desconto de Terra Fértil
    final fertileLandCount = _countControlledResources(playerId, ResourceType.fertileLand);
    if (fertileLandCount > 0) {
      custo *= 0.8; // 20% de desconto
    }

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
          _countOwned(playerId, Building.eficiencia) * 0.4; // Reduzido para crescimento gradual

      // Contar recursos de tesouro controlados
      final treasuryBonus = _countControlledResources(playerId, ResourceType.treasury) * 3.0; // Reduzido de 5 para 3

      // Orçamento base + bônus eficiência + impacto econômico + recursos (crescimento GRADUAL)
      playerState.orcamento += 3 + efficiencyBonus + playerState.economy.economicImpact + treasuryBonus; // Base reduzido de 6 para 3
    }

    _recomputeMetrics();
    _expandTerritories(); // Nova função de expansão
    _updateWorldClimate();
    _captureProgress();

    // Atualizar visibilidade (fog of war) para todos os jogadores
    for (final playerId in state.registeredPlayers) {
      _updateVisibility(playerId);
    }

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

      // Aplicar bônus de recursos estratégicos
      final energyBonusCount = _countControlledResources(playerId, ResourceType.energyBonus);
      final cleanSourceCount = _countControlledResources(playerId, ResourceType.cleanSource);
      final researchCount = _countControlledResources(playerId, ResourceType.research);

      effectiveClean += energyBonusCount * 0.2 * built; // +20% produção de energia

      var effectiveCleanRatio = built == 0 ? 0.0 : (effectiveClean / built).clamp(0, 1).toDouble();
      effectiveCleanRatio = (effectiveCleanRatio + cleanSourceCount * 0.15).clamp(0, 1).toDouble(); // +15% sustentabilidade

      var tarifa = _computeTarifa(acc.clean, built, acc.efficiency);
      var saude = (0.40 + acc.sanitation / territory * 0.60).clamp(0, 1).toDouble();
      var clima = (0.45 + effectiveClean / territory * 0.55).clamp(0, 1).toDouble();
      var educacao = (0.35 + acc.efficiency / territory * 0.55 + researchCount * 0.10).clamp(0, 1).toDouble(); // +10% educação

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
        ..educacao = educacao
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
    const radius = 1; // Apenas células adjacentes (distância 1)

    for (var dx = -radius; dx <= radius; dx++) {
      for (var dy = -radius; dy <= radius; dy++) {
        if (dx == 0 && dy == 0) continue;

        final x = centerX + dx;
        final y = centerY + dy;

        if (_outOfBounds(x, y)) continue;

        // Apenas distância Manhattan de 1 (4 direções cardeais, não diagonais)
        if (dx.abs() + dy.abs() > 1) continue;

        final key = '$x,$y';
        influenceMap.putIfAbsent(key, () => {});

        final currentInfluence = influenceMap[key]![playerId] ?? 0;

        // Diminishing returns: cada construção adicional contribui menos
        // 1ª construção: 100%, 2ª: 60%, 3ª: 40%, 4ª+: 25%
        double multiplier = 1.0;
        if (currentInfluence > 0) {
          if (currentInfluence < 1.5) {
            multiplier = 0.6; // Segunda construção
          } else if (currentInfluence < 2.5) {
            multiplier = 0.4; // Terceira construção
          } else {
            multiplier = 0.25; // Quarta+ construção
          }
        }

        influenceMap[key]![playerId] = currentInfluence + (baseInfluence * multiplier);
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

    // Coletar células conquistáveis por jogador
    final conquestCandidates = <String, List<(int, int, double, int)>>{}; // playerId -> [(x, y, influence, priority)]

    const decay = 0.9; // retém influência de turnos anteriores, mas reduz
    const threshold = 12.0; // exige vários turnos ou múltiplas construções

    for (final entry in influenceMap.entries) {
      final coords = entry.key.split(',');
      final x = int.parse(coords[0]);
      final y = int.parse(coords[1]);
      final cell = state.grid[x][y];

      // Atualizar mapa de influência na célula acumulando com decaimento
      final newInfluence = <String, double>{};
      for (final playerEntry in entry.value.entries) {
        final previous = cell.influence[playerEntry.key] ?? 0.0;
        final updated = previous * decay + playerEntry.value;
        newInfluence[playerEntry.key] = updated;
      }
      // Decair influências antigas sem entrada nova
      for (final oldEntry in cell.influence.entries) {
        if (newInfluence.containsKey(oldEntry.key)) continue;
        final decayed = oldEntry.value * decay;
        if (decayed > 0.01) {
          newInfluence[oldEntry.key] = decayed;
        }
      }
      cell.influence = newInfluence;

      // Só pode tomar território se célula estiver vazia
      if (cell.b == Building.vazio && cell.ownerId == null) {
        for (final playerEntry in cell.influence.entries) {
          if (playerEntry.value >= threshold) {
            final playerId = playerEntry.key;

            // Calcular prioridade da célula (recursos são mais importantes)
            var priority = 0;
            if (cell.resource != ResourceType.none) {
              priority = 100; // Células com recurso têm prioridade máxima
            }

            conquestCandidates.putIfAbsent(playerId, () => []);
            conquestCandidates[playerId]!.add((x, y, playerEntry.value, priority));
          }
        }
      }
    }

    // Para cada jogador, conquistar apenas a célula mais importante
    for (final entry in conquestCandidates.entries) {
      final playerId = entry.key;
      final candidates = entry.value;

      if (candidates.isEmpty) continue;

      // Ordenar por prioridade (recursos primeiro) e depois por influência
      candidates.sort((a, b) {
        final priorityCompare = b.$4.compareTo(a.$4); // Maior prioridade primeiro
        if (priorityCompare != 0) return priorityCompare;
        return b.$3.compareTo(a.$3); // Maior influência primeiro
      });

      // Conquistar apenas a célula mais importante
      final bestCandidate = candidates.first;
      final cell = state.grid[bestCandidate.$1][bestCandidate.$2];
      cell.ownerId = playerId;
      cell.justConquered = true;
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

  /// Conta quantos recursos de um tipo específico um jogador controla
  int _countControlledResources(String playerId, ResourceType resourceType) {
    int count = 0;
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        if (cell.ownerId == playerId && cell.resource == resourceType) {
          count++;
        }
      }
    }
    return count;
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

  /// Inicializa visibilidade para um jogador (tudo unexplored)
  void _initVisibility(String playerId) {
    _visibility[playerId] = List.generate(
      state.size,
      (_) => List.filled(state.size, VisibilityState.unexplored),
    );
  }

  /// Atualiza visibilidade baseado nos territórios do jogador
  void _updateVisibility(String playerId) {
    if (!_visibility.containsKey(playerId)) {
      _initVisibility(playerId);
    }

    final visibility = _visibility[playerId]!;

    // Primeiro, marcar tudo como explored (exceto unexplored que permanece)
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        if (visibility[x][y] == VisibilityState.visible) {
          visibility[x][y] = VisibilityState.explored;
        }
      }
    }

    // Revelar áreas ao redor de territórios controlados
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];

        // Se jogador controla esta célula, revelar área ao redor
        if (cell.ownerId == playerId) {
          _revealArea(playerId, x, y);
        }
      }
    }
  }

  /// Revela área ao redor de uma posição
  void _revealArea(String playerId, int centerX, int centerY) {
    final visibility = _visibility[playerId]!;

    for (var dx = -_visionRadius; dx <= _visionRadius; dx++) {
      for (var dy = -_visionRadius; dy <= _visionRadius; dy++) {
        final x = centerX + dx;
        final y = centerY + dy;

        if (!_outOfBounds(x, y)) {
          visibility[x][y] = VisibilityState.visible;
        }
      }
    }
  }

  /// Obtém estado de visibilidade de uma célula para o jogador local
  VisibilityState getCellVisibility(int x, int y) {
    if (!_visibility.containsKey(_localPlayerId)) {
      _initVisibility(_localPlayerId);
      _updateVisibility(_localPlayerId);
    }

    return _visibility[_localPlayerId]![x][y];
  }

  bool canControlCell(String playerId, int x, int y) {
    final cell = state.grid[x][y];

    // Só pode construir em células que já são do jogador
    if (cell.ownerId == playerId) {
      return true;
    }

    // Exceção: Se jogador não tem território ainda, pode colocar em qualquer célula vazia
    if (!playerHasAnyCell(playerId) && cell.ownerId == null) {
      return true;
    }

    // Não pode construir em células de outros jogadores ou células vazias
    return false;
  }

  void _centerCameraOnLocalSpawnIfNeeded() {
    if (_cameraCentered) return;

    final spawn = _playerSpawns[_localPlayerId] ?? _findFirstOwnedCell(_localPlayerId);
    if (spawn == null) return;

    _centerCameraOnCell(spawn.$1, spawn.$2);
    _cameraCentered = true;
  }

  (int, int)? _findFirstOwnedCell(String playerId) {
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        if (state.grid[x][y].ownerId == playerId) {
          return (x, y);
        }
      }
    }
    return null;
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
          final loadedState = GameState.fromJson(decoded);

          // Se o mapa salvo for muito pequeno (antigo), descartar e criar novo
          if (loadedState.size < 40) {
            state = GameState(size: state.size);
            restart(); // Reiniciar com novo mapa
          } else {
            state = loadedState;
          }
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

    // Se não tem território inicial, criar spawns
    if (!playerHasAnyCell(_localPlayerId)) {
      initializePlayerSpawns();
      _recomputeMetrics();
      saveGame();
    }
  }

  // ===== Sistema de Pan/Scroll do Mapa =====

  Vector2? _panStartPosition;
  Vector2? _cameraStartPosition;

  @override
  void onPanStart(DragStartInfo info) {
    _panStartPosition = info.eventPosition.global;
    _cameraStartPosition = camera.viewfinder.position.clone();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_panStartPosition == null || _cameraStartPosition == null) return;

    final delta = info.eventPosition.global - _panStartPosition!;
    camera.viewfinder.position = _cameraStartPosition! - delta;

    // Limitar o pan para não sair do mapa
    final gridPixelSize = state.size * tileSize;
    camera.viewfinder.position.x = camera.viewfinder.position.x.clamp(
      -gridPixelSize * 0.2,
      gridPixelSize * 0.2,
    );
    camera.viewfinder.position.y = camera.viewfinder.position.y.clamp(
      -gridPixelSize * 0.2,
      gridPixelSize * 0.2,
    );
  }

  @override
  void onPanEnd(DragEndInfo info) {
    _panStartPosition = null;
    _cameraStartPosition = null;
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

  /// Calcula progresso parcial de cada tipo de vitória (0.0 a 1.0)
  Map<String, Map<VictoryType, double>> calculateVictoryProgress() {
    final progress = <String, Map<VictoryType, double>>{};
    const econBase = 20.0;
    const econTarget = 300.0;
    const baseEdu = 0.5;
    const baseTarifa = 1.0;
    const minTarifa = 0.55; // limite inferior de tarifa no jogo
    const baseClima = 0.6; // valor inicial
    const targetClima = 0.7; // requisito para vitória coletiva
    const baseTerritory = 9.0; // 3x3 inicial
    final totalCells = (state.size * state.size).toDouble();

    for (final playerId in state.registeredPlayers) {
      final playerState = _playerState(playerId);
      final metrics = playerState.metrics;
      final territory = state.getTerritorySize(playerId);

      final sustentabilidade = ((metrics.acessoEnergia + metrics.limpa) / 2.0).clamp(0, 1).toDouble();
      final economia = ((playerState.orcamento - econBase) / (econTarget - econBase)).clamp(0, 1).toDouble();

      final relativeEdu = ((metrics.educacao - baseEdu) / (1 - baseEdu)).clamp(0, 1).toDouble();
      final relativeTarifa = ((baseTarifa - metrics.tarifa) / (baseTarifa - minTarifa)).clamp(0, 1).toDouble();
      final ciencia = ((relativeEdu + relativeTarifa) / 2.0).clamp(0, 1).toDouble();

      final territorial =
          ((territory - baseTerritory) / (totalCells - baseTerritory)).clamp(0, 1).toDouble();

      final coletivo = ((state.metrics.clima - baseClima) / (targetClima - baseClima)).clamp(0, 1).toDouble();

      progress[playerId] = {
        VictoryType.sustentavel: sustentabilidade,
        VictoryType.economica: economia,
        VictoryType.cientifica: ciencia,
        VictoryType.territorial: territorial,
        VictoryType.coletiva: coletivo,
      };
    }

    return progress;
  }

  /// Retorna o líder em cada tipo de vitória
  Map<VictoryType, String> getVictoryLeaders() {
    final progress = calculateVictoryProgress();
    final leaders = <VictoryType, String>{};

    for (final victoryType in VictoryType.values) {
      String? leader;
      double maxProgress = 0.0;

      for (final entry in progress.entries) {
        final playerId = entry.key;
        final playerProgress = entry.value[victoryType] ?? 0.0;

        if (playerProgress > maxProgress) {
          maxProgress = playerProgress;
          leader = playerId;
        }
      }

      if (leader != null) {
        leaders[victoryType] = leader;
      }
    }

    return leaders;
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
