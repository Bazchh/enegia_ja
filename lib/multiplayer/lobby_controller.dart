import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_socket.dart';
import 'multiplayer_game.dart';

class LobbyPlayer {
  LobbyPlayer({required this.id, required this.color, this.ready = false});

  final String id;
  String color;
  bool ready;

  LobbyPlayer copyWith({String? color, bool? ready}) => LobbyPlayer(
        id: id,
        color: color ?? this.color,
        ready: ready ?? this.ready,
      );

  Map<String, dynamic> toJson() => {
        'color': color,
        'ready': ready,
      };

  static LobbyPlayer fromJson(String id, Map<String, dynamic> json) =>
      LobbyPlayer(
        id: id,
        color: json['color']?.toString() ?? LobbyController.defaultColor,
        ready: json['ready'] == true,
      );
}

class LobbyChatMessage {
  LobbyChatMessage({
    required this.playerId,
    required this.message,
    required this.timestamp,
  });

  final String playerId;
  final String message;
  final DateTime timestamp;
}

class LobbyController extends ChangeNotifier {
  LobbyController({String? roomId, required this.isHost})
      : socket = GameSocket(roomId: roomId);

  final GameSocket socket;
  final bool isHost;

  final Map<String, LobbyPlayer> _players = {};
  final List<String> _order = [];
  final List<LobbyChatMessage> _chat = [];

  Timer? _countdownTimer;
  int? _countdownSeconds;
  bool _gameStarting = false;
  bool _initialized = false;
  String? _errorMessage;
  bool _handedOffToGame = false;

  static const List<String> _palette = [
    '#F44336', // red
    '#2196F3', // blue
    '#4CAF50', // green
    '#FF9800', // orange
    '#9C27B0', // purple
    '#009688', // teal
    '#795548', // brown
    '#607D8B', // blue grey
  ];

  static String get defaultColor => _palette.first;

  Future<void> initialize() async {
    _attachSocketListeners();
    final connected = await socket.connect();
    if (!connected) {
      _errorMessage = 'Falha ao conectar ao servidor';
      notifyListeners();
      return;
    }

    if (isHost) {
      final color = _nextAvailableColor();
      final hostPlayer = LobbyPlayer(id: socket.playerId, color: color);
      _players[socket.playerId] = hostPlayer;
      _order.add(socket.playerId);
      notifyListeners();
      _broadcastLobbyState();
    } else {
      _players[socket.playerId] =
          LobbyPlayer(id: socket.playerId, color: defaultColor);
      notifyListeners();
    }

    _initialized = true;
    notifyListeners();
  }

  bool get initialized => _initialized;
  bool get gameStarting => _gameStarting;
  String get roomId => socket.roomId;
  String? get errorMessage => _errorMessage;

  List<LobbyPlayer> get players =>
      _order.map((id) => _players[id]).whereType<LobbyPlayer>().toList();

  LobbyPlayer? get localPlayer => _players[socket.playerId];

  bool get isLocalReady => localPlayer?.ready ?? false;

  List<LobbyChatMessage> get chatMessages => List.unmodifiable(_chat);

  int? get countdownSeconds => _countdownSeconds;

  List<String> get availableColors {
    final localId = socket.playerId;
    final used = _players.values
        .where((player) => player.id != localId)
        .map((player) => player.color)
        .toSet();
    return _palette
        .where((color) => !used.contains(color) || localPlayer?.color == color)
        .toList();
  }

  void toggleReady() {
    final player = localPlayer;
    if (player == null) return;
    final next = !player.ready;

    if (isHost) {
      player.ready = next;
      if (!next) {
        _cancelCountdown();
      }
      _broadcastLobbyState();
      _evaluateCountdown();
    } else {
      player.ready = next; // feedback otimista
      socket.sendReadyState(next);
    }
    notifyListeners();
  }

  void setColor(String color) {
    final player = localPlayer;
    if (player == null || player.color == color) return;

    if (isHost) {
      final assigned = _assignColor(player.id, preferred: color);
      player.color = assigned;
      _broadcastLobbyState();
    } else {
      player.color = color;
      socket.sendColorChoice(color);
    }
    notifyListeners();
  }

  void sendChat(String text) {
    final message = text.trim();
    if (message.isEmpty) return;
    _appendChat(
      playerId: socket.playerId,
      message: message,
      timestamp: DateTime.now(),
    );
    socket.sendChat(message);
    notifyListeners();
  }

  Map<String, LobbyPlayer> get playerMap => Map.unmodifiable(_players);

  List<String> get playerOrder => List.unmodifiable(_order);

  MultiplayerGame buildGame() {
    _cancelCountdown();
    _detachSocketListeners();
    _handedOffToGame = true;
    return MultiplayerGame(
      existingSocket: socket,
      isHost: isHost,
      initialPlayers: playerOrder,
    );
  }

  @override
  void dispose() {
    _cancelCountdown();
    _detachSocketListeners();
    if (!_handedOffToGame) {
      socket.disconnect();
    }
    super.dispose();
  }

  // ===== Socket listeners =====

  void _attachSocketListeners() {
    socket.onPlayerJoined = _handlePlayerJoined;
    socket.onPlayerLeft = _handlePlayerLeft;
    socket.onLobbyState = _handleLobbyState;
    socket.onLobbyCommand = _handleLobbyCommand;
    socket.onChatMessage = _handleChatMessage;
    socket.onCountdown = _handleCountdown;
    socket.onStartGame = _handleStartGame;
    socket.onError = (error) {
      _errorMessage = error;
      notifyListeners();
    };
  }

  void _detachSocketListeners() {
    socket.onPlayerJoined = null;
    socket.onPlayerLeft = null;
    socket.onLobbyState = null;
    socket.onLobbyCommand = null;
    socket.onChatMessage = null;
    socket.onCountdown = null;
    socket.onStartGame = null;
    socket.onError = null;
  }

  void _handlePlayerJoined(String playerId, String roomId) {
    if (!isHost) return;
    if (_players.containsKey(playerId)) return;
    final color = _nextAvailableColor();
    _players[playerId] = LobbyPlayer(id: playerId, color: color);
    _order.add(playerId);
    _cancelCountdown();
    _broadcastLobbyState();
    notifyListeners();
  }

  void _handlePlayerLeft(String playerId) {
    _players.remove(playerId);
    _order.remove(playerId);
    if (isHost) {
      _cancelCountdown();
      _broadcastLobbyState();
      _evaluateCountdown();
    }
    notifyListeners();
  }

  void _handleLobbyState(Map<String, dynamic> data) {
    final playersData = data['players'] as Map<String, dynamic>? ?? {};
    final orderData = data['order'] as List<dynamic>?;

    _players
      ..clear()
      ..addEntries(playersData.entries.map((entry) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          return MapEntry(entry.key, LobbyPlayer.fromJson(entry.key, value));
        }
        return MapEntry(entry.key, LobbyPlayer(id: entry.key, color: defaultColor));
      }));

    _order
      ..clear()
      ..addAll(orderData == null
          ? _players.keys
          : orderData.map((e) => e.toString()));

    if (data.containsKey('seconds')) {
      final rawSeconds = data['seconds'];
      int? seconds;
      if (rawSeconds is num) {
        seconds = rawSeconds.toInt();
      }
      if (seconds != null && seconds < 0) {
        seconds = null;
      }
      _countdownSeconds = seconds;
    }
    notifyListeners();
  }

  void _handleLobbyCommand(String playerId, Map<String, dynamic> payload) {
    if (!isHost) return;
    final player = _players[playerId] ??
        LobbyPlayer(id: playerId, color: _nextAvailableColor());
    _players[playerId] = player;
    if (!_order.contains(playerId)) {
      _order.add(playerId);
    }

    if (payload.containsKey('ready')) {
      final ready = payload['ready'] == true;
      player.ready = ready;
      if (!ready) {
        _cancelCountdown();
      }
      _broadcastLobbyState();
      _evaluateCountdown();
    }

    if (payload.containsKey('color')) {
      final desired = payload['color']?.toString();
      final assigned = _assignColor(playerId, preferred: desired);
      player.color = assigned;
      _broadcastLobbyState();
    }
  }

  void _handleChatMessage(String playerId, String message) {
    if (playerId == socket.playerId) {
      return;
    }
    _appendChat(
      playerId: playerId,
      message: message,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void _handleCountdown(int seconds) {
    if (seconds < 0) {
      _countdownSeconds = null;
    } else {
      _countdownSeconds = seconds;
    }
    notifyListeners();
  }

  void _handleStartGame() {
    _gameStarting = true;
    notifyListeners();
  }

  void _broadcastLobbyState() {
    if (!isHost) return;
    final playersJson = {
      for (final entry in _players.entries) entry.key: entry.value.toJson(),
    };
    socket.sendLobbyState(
      playersJson,
      order: List<String>.from(_order),
      seconds: _countdownSeconds,
    );
  }

  void _evaluateCountdown() {
    if (!isHost) return;
    if (_players.isEmpty) return;
    final everyoneReady =
        _players.values.isNotEmpty && _players.values.every((p) => p.ready);
    if (everyoneReady && _countdownTimer == null) {
      _startCountdown();
    } else if (!everyoneReady) {
      _cancelCountdown();
    }
  }

  void _startCountdown() {
    _countdownSeconds = 10;
    socket.sendCountdown(_countdownSeconds!);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == null) {
        timer.cancel();
        _countdownTimer = null;
        return;
      }
      _countdownSeconds = (_countdownSeconds ?? 1) - 1;
      if (_countdownSeconds! > 0) {
        socket.sendCountdown(_countdownSeconds!);
      } else {
        timer.cancel();
        _countdownTimer = null;
        socket.sendCountdown(0);
        _startGameHost();
      }
      notifyListeners();
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdownSeconds != null) {
      _countdownSeconds = null;
      if (isHost) {
        socket.sendCountdown(-1);
      }
      notifyListeners();
    }
  }

  void _startGameHost() {
    if (!isHost || _gameStarting) return;
    _gameStarting = true;
    socket.sendStartGameSignal();
    notifyListeners();
  }

  String _assignColor(String playerId, {String? preferred}) {
    if (preferred != null && !_isColorTaken(preferred, except: playerId)) {
      return preferred;
    }
    return _nextAvailableColor(except: playerId);
  }

  bool _isColorTaken(String color, {String? except}) {
    return _players.values.any(
      (player) => player.color == color && player.id != except,
    );
  }

  String _nextAvailableColor({String? preferred, String? except}) {
    final candidates = [
      if (preferred != null) preferred,
      ..._palette,
    ];
    for (final color in candidates) {
      if (!_isColorTaken(color, except: except)) {
        return color;
      }
    }
    return defaultColor;
  }

  void _appendChat({
    required String playerId,
    required String message,
    required DateTime timestamp,
  }) {
    _chat.add(
      LobbyChatMessage(
        playerId: playerId,
        message: message,
        timestamp: timestamp,
      ),
    );
    if (_chat.length > 200) {
      _chat.removeAt(0);
    }
  }
}
