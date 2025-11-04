import 'package:flutter/material.dart';

import '../game/energy_game.dart';
import '../game/state/game_state.dart';
import 'game_socket.dart';

class MultiplayerGame extends EnergyGame {
  static const List<Color> _fallbackColors = [
    Colors.lightBlueAccent,
    Colors.redAccent,
    Colors.lightGreenAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
  ];

  final GameSocket socket;
  final bool isHost;
  final bool _ownsSocket;

  final List<String> _playerOrder = [];
  final Set<String> _playersReady = <String>{};
  bool _isApplyingRemoteAction = false;

  MultiplayerGame({
    String? roomId,
    GameSocket? existingSocket,
    this.isHost = false,
    List<String>? initialPlayers,
    Map<String, String>? playerColors,
  })  : socket = existingSocket ?? GameSocket(roomId: roomId),
        _ownsSocket = existingSocket == null,
        super() {
    setLocalPlayer(socket.playerId);
    _applyPlayerColors(playerColors);
    _registerSocketCallbacks();
    _initPlayerOrder(initialPlayers);

    if (_ownsSocket) {
      socket.connect().then((connected) {
        if (!connected) return;
        _onConnected();
      });
    } else {
      _onConnected();
    }
  }

  @override
  Future<void> loadGame() async {
    restart();
  }

  bool get canAct =>
      !_playersReady.contains(socket.playerId) && !state.acabou();

  bool get hasEndedTurn => _playersReady.contains(socket.playerId);

  List<String> get players => List.unmodifiable(_playerOrder);

  Map<String, bool> get readiness => {
        for (final player in _playerOrder) player: _playersReady.contains(player),
      };

  void _registerSocketCallbacks() {
    socket.onStateUpdate = _handleRemoteStateUpdate;
    socket.onPlayerJoined = _handlePlayerJoined;
    socket.onPlayerLeft = _handlePlayerLeft;
    socket.onError = _handleError;
    socket.onActionRequest = _handleActionRequest;
    socket.onTurnUpdate = _handleTurnUpdate;
  }

  void _initPlayerOrder(List<String>? initialPlayers) {
    if (initialPlayers != null && initialPlayers.isNotEmpty) {
      _playerOrder
        ..clear()
        ..addAll(initialPlayers);
    }

    if (!_playerOrder.contains(socket.playerId)) {
      _playerOrder.add(socket.playerId);
    }
  }

  void _applyPlayerColors(Map<String, String>? playerColors) {
    if (playerColors == null) return;
    for (final entry in playerColors.entries) {
      final color = _parseColor(entry.value);
      setOwnerColor(entry.key, color);
    }
  }

  void _onConnected() {
    if (!isHost) return;
    _ensureStartingTerritories();
    _broadcastTurnInfo();
    _syncGameState();
  }

  @override
  PlaceResult placeAt(int x, int y, {String? actingPlayerId}) {
    if (_isApplyingRemoteAction) {
      return super.placeAt(x, y, actingPlayerId: actingPlayerId);
    }

    if (!canAct) {
      lastPlaceResult = null;
      return PlaceResult.invalido;
    }

    if (!isHost) {
      if (removeMode) {
        final cell = state.grid[x][y];
        if (cell.ownerId != socket.playerId || cell.b == Building.vazio) {
          lastPlaceResult = PlaceResult.invalido;
          return PlaceResult.invalido;
        }
      } else if (!canControlCell(socket.playerId, x, y)) {
        lastPlaceResult = PlaceResult.invalido;
        return PlaceResult.invalido;
      }

      final action = removeMode ? 'remove' : 'place';
      socket.sendActionRequest({'action': action, 'x': x, 'y': y});
      lastPlaceResult = null;
      return PlaceResult.ok;
    }

    final result = super.placeAt(x, y, actingPlayerId: socket.playerId);
    if (result == PlaceResult.ok || result == PlaceResult.removido) {
      _syncGameState();
    }
    return result;
  }

  @override
  void endTurn() {
    if (hasEndedTurn || state.acabou()) return;

    _playersReady.add(socket.playerId);
    _broadcastTurnInfo();

    if (!isHost) {
      socket.sendActionRequest({'action': 'end_turn'});
      return;
    }

    _evaluateTurnCompletion();
  }

  void _syncGameState() {
    if (isHost) {
      socket.sendGameState(state);
    }
  }

  void _handleRemoteStateUpdate(GameState remoteState) {
    if (isHost) {
      state.turno = remoteState.turno;
      state.orcamento = remoteState.orcamento;
      state.metrics
        ..acessoEnergia = remoteState.metrics.acessoEnergia
        ..limpa = remoteState.metrics.limpa
        ..tarifa = remoteState.metrics.tarifa
        ..saude = remoteState.metrics.saude
        ..educacao = remoteState.metrics.educacao
        ..desigualdade = remoteState.metrics.desigualdade
        ..clima = remoteState.metrics.clima;
      state.grid = remoteState.grid;
      _refreshColorsFromState();
    } else {
      state.turno = remoteState.turno;
      state.orcamento = remoteState.orcamento;
      state.metrics
        ..acessoEnergia = remoteState.metrics.acessoEnergia
        ..limpa = remoteState.metrics.limpa
        ..tarifa = remoteState.metrics.tarifa
        ..saude = remoteState.metrics.saude
        ..educacao = remoteState.metrics.educacao
        ..desigualdade = remoteState.metrics.desigualdade
        ..clima = remoteState.metrics.clima;
      state.grid = remoteState.grid;
      _refreshColorsFromState();
    }
  }

  void _handlePlayerJoined(String playerId, String roomId) {
    debugPrint('Jogador $playerId entrou na sala $roomId');

    if (!_playerOrder.contains(playerId)) {
      _playerOrder.add(playerId);
    }
    _playersReady.remove(playerId);

    if (!isHost) {
      _broadcastTurnInfo();
      return;
    }

    final changed = _ensureStartingTerritories();
    _broadcastTurnInfo();
    if (changed) {
      _syncGameState();
    }
  }

  void _handlePlayerLeft(String playerId) {
    debugPrint('Jogador $playerId saiu');

    _playerOrder.remove(playerId);
    _playersReady.remove(playerId);

    if (isHost) {
      _releaseTerritory(playerId);
    }

    if (_playerOrder.isEmpty) {
      _playerOrder.add(socket.playerId);
    }

    if (!isHost) {
      _broadcastTurnInfo();
      return;
    }

    final changed = _ensureStartingTerritories();
    _broadcastTurnInfo();
    if (changed) {
      _syncGameState();
    } else {
      _evaluateTurnCompletion();
    }
  }

  void _handleError(String error) {
    debugPrint('Erro de conexao: $error');
  }

  void _handleActionRequest(String playerId, Map<String, dynamic> payload) {
    if (!isHost || playerId == socket.playerId) {
      return;
    }

    if (_playersReady.contains(playerId)) {
      // Ignora ações de quem já finalizou o turno
      return;
    }

    final action = payload['action'] as String?;
    final x = payload['x'] as int?;
    final y = payload['y'] as int?;

    if (action == null) {
      return;
    }

    switch (action) {
      case 'place':
        if (x == null || y == null) return;
        _applyRemotePlacement(playerId, x, y);
        break;
      case 'remove':
        if (x == null || y == null) return;
        _applyRemoteRemoval(playerId, x, y);
        break;
      case 'end_turn':
        _playersReady.add(playerId);
        _evaluateTurnCompletion();
        break;
    }
  }

  void _applyRemotePlacement(String playerId, int x, int y) {
    _isApplyingRemoteAction = true;
    final previousRemoveMode = removeMode;
    removeMode = false;
    final result = super.placeAt(x, y, actingPlayerId: playerId);
    removeMode = previousRemoveMode;
    _isApplyingRemoteAction = false;

    if (result == PlaceResult.ok) {
      _syncGameState();
    }
  }

  void _applyRemoteRemoval(String playerId, int x, int y) {
    _isApplyingRemoteAction = true;
    final previousRemoveMode = removeMode;
    removeMode = true;
    final result = super.placeAt(x, y, actingPlayerId: playerId);
    removeMode = previousRemoveMode;
    _isApplyingRemoteAction = false;

    if (result == PlaceResult.removido) {
      _syncGameState();
    }
  }

  void _handleTurnUpdate(TurnUpdateMessage message) {
    _playerOrder
      ..clear()
      ..addAll(message.players);

    _playersReady
      ..clear()
      ..addAll(message.readyPlayers);

    state.turno = message.turn;

    removeMode = false;
    lastPlaceResult = null;
  }

  void _evaluateTurnCompletion() {
    _broadcastTurnInfo();

    if (_playerOrder.isEmpty ||
        _playersReady.length < _playerOrder.length) {
      return;
    }

    super.endTurn();
    _playersReady.clear();
    removeMode = false;
    lastPlaceResult = null;
    _broadcastTurnInfo();
    _syncGameState();
  }

  void _broadcastTurnInfo() {
    if (!isHost) return;
    socket.sendTurnInfo(
      players: List.unmodifiable(_playerOrder),
      readyPlayers: List.unmodifiable(_playersReady),
      turn: state.turno,
    );
  }

  bool _ensureStartingTerritories() {
    if (!isHost) return false;
    var changed = false;

    for (var i = 0; i < _playerOrder.length; i++) {
      final playerId = _playerOrder[i];
      _ensureColorForPlayer(playerId, i);
      if (playerHasAnyCell(playerId)) {
        continue;
      }
      changed = true;
      _assignTerritory(playerId, i);
    }

    return changed;
  }

  void _assignTerritory(String playerId, int index) {
    _ensureColorForPlayer(playerId, index);
    final centers = [
      [1, 1],
      [state.size - 2, state.size - 2],
      [1, state.size - 2],
      [state.size - 2, 1],
    ];
    final center = centers[index % centers.length];
    final cx = center[0].clamp(0, state.size - 1);
    final cy = center[1].clamp(0, state.size - 1);

    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= state.size || ny >= state.size) {
          continue;
        }
        final cell = state.grid[nx][ny];
        cell.ownerId ??= playerId;
      }
    }
  }

  void _ensureColorForPlayer(String playerId, int index) {
    if (hasOwnerColor(playerId)) {
      return;
    }
    final color = _fallbackColors[index % _fallbackColors.length];
    setOwnerColor(playerId, color);
  }

  void _refreshColorsFromState() {
    final owners = <String>{};
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final ownerId = state.grid[x][y].ownerId;
        if (ownerId != null) {
          owners.add(ownerId);
        }
      }
    }
    var index = 0;
    for (final owner in owners) {
      _ensureColorForPlayer(owner, index++);
    }
  }

  void _releaseTerritory(String playerId) {
    for (var x = 0; x < state.size; x++) {
      for (var y = 0; y < state.size; y++) {
        final cell = state.grid[x][y];
        if (cell.ownerId == playerId) {
          cell.ownerId = null;
        }
      }
    }
  }

  Color _parseColor(String value) {
    var hex = value.toUpperCase().replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  void onRemove() {
    socket.disconnect();
    super.onRemove();
  }
}
