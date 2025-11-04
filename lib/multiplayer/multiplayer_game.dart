import 'package:flutter/foundation.dart';

import '../game/energy_game.dart';
import '../game/state/game_state.dart';
import 'game_socket.dart';

class MultiplayerGame extends EnergyGame {
  final GameSocket socket;
  final bool isHost;
  final bool _ownsSocket;

  final List<String> _playerOrder = [];
  String? _currentPlayerId;
  bool _isApplyingRemoteAction = false;

  bool get isLocalTurn =>
      _currentPlayerId != null && _currentPlayerId == socket.playerId;
  List<String> get players => List.unmodifiable(_playerOrder);
  String? get currentPlayerId => _currentPlayerId;

  void _registerSocketCallbacks() {
    socket.onStateUpdate = _handleRemoteStateUpdate;
    socket.onPlayerJoined = _handlePlayerJoined;
    socket.onPlayerLeft = _handlePlayerLeft;
    socket.onError = _handleError;
    socket.onActionRequest = _handleActionRequest;
    socket.onTurnUpdate = _handleTurnUpdate;
  }

  void _onConnected() {
    if (!isHost) return;
    if (_playerOrder.isEmpty) {
      _playerOrder.add(socket.playerId);
    }
    _currentPlayerId ??= _playerOrder.first;
    _broadcastTurnInfo();
    _syncGameState();
  }

  MultiplayerGame({
    String? roomId,
    GameSocket? existingSocket,
    this.isHost = false,
    List<String>? initialPlayers,
  })  : socket = existingSocket ?? GameSocket(roomId: roomId),
        _ownsSocket = existingSocket == null,
        super() {
    _registerSocketCallbacks();

    if (initialPlayers != null && initialPlayers.isNotEmpty) {
      _playerOrder
        ..clear()
        ..addAll(initialPlayers);
    } else if (!_playerOrder.contains(socket.playerId)) {
      _playerOrder.add(socket.playerId);
    }

    if (isHost) {
      _currentPlayerId =
          _playerOrder.isNotEmpty ? _playerOrder.first : socket.playerId;
    }

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
  PlaceResult placeAt(int x, int y) {
    if (_isApplyingRemoteAction) {
      return super.placeAt(x, y);
    }

    if (!isLocalTurn) {
      lastPlaceResult = null;
      return PlaceResult.invalido;
    }

    if (!isHost) {
      final action = removeMode ? 'remove' : 'place';
      socket.sendActionRequest({'action': action, 'x': x, 'y': y});
      lastPlaceResult = null;
      return PlaceResult.ok;
    }

    final result = super.placeAt(x, y);
    if (result == PlaceResult.ok || result == PlaceResult.removido) {
      _syncGameState();
    }
    return result;
  }

  @override
  void endTurn() {
    if (!isLocalTurn) return;

    if (!isHost) {
      socket.sendActionRequest({'action': 'end_turn'});
      return;
    }

    super.endTurn();
    _syncGameState();
    _advanceTurn();
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
    }
  }

  void _handlePlayerJoined(String playerId, String roomId) {
    debugPrint('Jogador $playerId entrou na sala $roomId');

    if (!isHost) {
      return;
    }

    if (!_playerOrder.contains(playerId)) {
      _playerOrder.add(playerId);
    }
    _currentPlayerId ??= socket.playerId;
    _broadcastTurnInfo();
    _syncGameState();
  }

  void _handlePlayerLeft(String playerId) {
    debugPrint('Jogador $playerId saiu');

    if (!isHost) {
      return;
    }

    final wasCurrent = _currentPlayerId == playerId;
    _playerOrder.remove(playerId);

    if (_playerOrder.isEmpty) {
      _playerOrder.add(socket.playerId);
    }

    if (wasCurrent || !_playerOrder.contains(_currentPlayerId)) {
      _currentPlayerId = _playerOrder.first;
    }

    _broadcastTurnInfo();
    _syncGameState();
  }

  void _handleError(String error) {
    debugPrint('Erro de conexao: $error');
  }

  void _handleActionRequest(String playerId, Map<String, dynamic> payload) {
    if (!isHost || playerId == socket.playerId) {
      return;
    }

    final action = payload['action'] as String?;
    final x = payload['x'] as int?;
    final y = payload['y'] as int?;

    if (action == null) {
      return;
    }

    if (playerId != _currentPlayerId) {
      _broadcastTurnInfo();
      return;
    }

    switch (action) {
      case 'place':
        if (x == null || y == null) return;
        _applyRemotePlacement(x, y);
        break;
      case 'remove':
        if (x == null || y == null) return;
        _applyRemoteRemoval(x, y);
        break;
      case 'end_turn':
        super.endTurn();
        _syncGameState();
        _advanceTurn();
        break;
    }
  }

  void _applyRemotePlacement(int x, int y) {
    _isApplyingRemoteAction = true;
    final previousRemoveMode = removeMode;
    removeMode = false;
    final result = super.placeAt(x, y);
    removeMode = previousRemoveMode;
    _isApplyingRemoteAction = false;

    if (result == PlaceResult.ok) {
      _syncGameState();
    }
  }

  void _applyRemoteRemoval(int x, int y) {
    _isApplyingRemoteAction = true;
    final previousRemoveMode = removeMode;
    removeMode = true;
    final result = super.placeAt(x, y);
    removeMode = previousRemoveMode;
    _isApplyingRemoteAction = false;

    if (result == PlaceResult.removido) {
      _syncGameState();
    }
  }

  void _handleTurnUpdate(String currentId, List<String> players) {
    _playerOrder
      ..clear()
      ..addAll(players);

    if (_playerOrder.isEmpty) {
      _currentPlayerId = null;
    } else if (currentId.isEmpty) {
      _currentPlayerId = _playerOrder.first;
    } else if (_playerOrder.contains(currentId)) {
      _currentPlayerId = currentId;
    } else {
      _currentPlayerId = _playerOrder.first;
    }

    removeMode = false;
    lastPlaceResult = null;
  }

  void _advanceTurn() {
    if (_playerOrder.isEmpty) {
      _playerOrder.add(socket.playerId);
    }

    _currentPlayerId ??= _playerOrder.first;

    final currentIndex = _playerOrder.indexOf(_currentPlayerId!);
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % _playerOrder.length;
    _currentPlayerId = _playerOrder[nextIndex];
    _broadcastTurnInfo();
  }

  void _broadcastTurnInfo() {
    if (!isHost || _currentPlayerId == null) {
      return;
    }
    socket.sendTurnInfo(_currentPlayerId!, List.unmodifiable(_playerOrder));
  }

  @override
  void onRemove() {
    socket.disconnect();
    super.onRemove();
  }
}
