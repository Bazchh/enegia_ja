import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../game/state/game_state.dart';

const _defaultWsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'wss://enegia-ja.onrender.com',
);

class TurnUpdateMessage {
  TurnUpdateMessage({
    required this.players,
    required this.readyPlayers,
    required this.turn,
  });

  final List<String> players;
  final List<String> readyPlayers;
  final int turn;
}

class GameSocket {
  final String playerId;
  final String roomId;
  final String _endpoint;
  WebSocketChannel? _channel;

  // Game callbacks
  Function(GameState)? onStateUpdate;
  Function(String, String)? onPlayerJoined;
  Function(String)? onPlayerLeft;
  Function(String)? onError;
  Function(String, Map<String, dynamic>)? onActionRequest;
  Function(TurnUpdateMessage)? onTurnUpdate;

  // Lobby callbacks
  Function(Map<String, dynamic>)? onLobbyState;
  Function(String, Map<String, dynamic>)? onLobbyCommand;
  Function(String, String)? onChatMessage;
  Function(int)? onCountdown;
  Function()? onStartGame;

  GameSocket({String? roomId, String? endpoint})
      : playerId = const Uuid().v4(),
        roomId = roomId ?? _generateRoomCode(),
        _endpoint = endpoint ?? _defaultWsUrl;

  bool get isConnected => _channel != null;

  Future<bool> connect() async {
    if (isConnected) {
      return true;
    }
    try {
      final uri = Uri.parse(_endpoint);
      _channel = WebSocketChannel.connect(uri);

      _sendMessage({
        'type': 'join',
        'playerId': playerId,
        'roomId': roomId,
      });

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          if (onError != null) onError!(error.toString());
        },
        onDone: () {
          _channel = null;
        },
      );

      return true;
    } catch (e) {
      if (onError != null) onError!(e.toString());
      return false;
    }
  }

  void disconnect() {
    if (isConnected) {
      _sendMessage({
        'type': 'leave',
        'playerId': playerId,
        'roomId': roomId,
      });
      _channel?.sink.close();
      _channel = null;
    }
  }

  // ===== Game messaging =====

  void sendGameState(GameState state) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'state_update',
      'playerId': playerId,
      'roomId': roomId,
      'state': state.toJson(),
    });
  }

  void sendActionRequest(Map<String, dynamic> payload) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'action_request',
      'playerId': playerId,
      'roomId': roomId,
      ...payload,
    });
  }

  void sendTurnInfo({
    required List<String> players,
    required List<String> readyPlayers,
    required int turn,
  }) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'turn_update',
      'playerId': playerId,
      'roomId': roomId,
      'players': players,
      'readyPlayers': readyPlayers,
      'turn': turn,
    });
  }

  // ===== Lobby messaging =====

  void sendLobbyState(
    Map<String, dynamic> players, {
    List<String>? order,
    int? seconds,
  }) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'lobby_state',
      'playerId': playerId,
      'roomId': roomId,
      'players': players,
      if (order != null) 'order': order,
      if (seconds != null) 'seconds': seconds,
    });
  }

  void sendReadyState(bool ready) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'ready_update',
      'playerId': playerId,
      'roomId': roomId,
      'ready': ready,
    });
  }

  void sendColorChoice(String colorHex) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'color_update',
      'playerId': playerId,
      'roomId': roomId,
      'color': colorHex,
    });
  }

  void sendChat(String message) {
    if (!isConnected || message.trim().isEmpty) return;
    _sendMessage({
      'type': 'chat',
      'playerId': playerId,
      'roomId': roomId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendCountdown(int seconds) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'countdown',
      'playerId': playerId,
      'roomId': roomId,
      'seconds': seconds,
    });
  }

  void sendStartGameSignal() {
    if (!isConnected) return;
    _sendMessage({
      'type': 'start_game',
      'playerId': playerId,
      'roomId': roomId,
    });
  }

  void _sendMessage(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'state_update':
          if (data['playerId'] != playerId && onStateUpdate != null) {
            final state = GameState.fromJson(data['state']);
            onStateUpdate!(state);
          }
          break;
        case 'join':
          if (data['playerId'] != playerId && onPlayerJoined != null) {
            onPlayerJoined!(data['playerId'], data['roomId']);
          }
          break;
        case 'leave':
          if (onPlayerLeft != null) {
            onPlayerLeft!(data['playerId']);
          }
          break;
        case 'action_request':
          if (onActionRequest != null) {
            final payload = Map<String, dynamic>.from(data)
              ..remove('type')
              ..remove('roomId')
              ..remove('playerId');
            onActionRequest!(data['playerId'], payload);
          }
          break;
        case 'turn_update':
          if (onTurnUpdate != null) {
            final players = (data['players'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            final readyPlayers = (data['readyPlayers'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];
            final turn = data['turn'] is num ? (data['turn'] as num).toInt() : 1;
            onTurnUpdate!(
              TurnUpdateMessage(
                players: players,
                readyPlayers: readyPlayers,
                turn: turn,
              ),
            );
          }
          break;
        case 'lobby_state':
          if (onLobbyState != null) {
            final players =
                Map<String, dynamic>.from(data['players'] ?? <String, dynamic>{});
            final payload = <String, dynamic>{
              'players': players,
            };
            if (data['order'] is List) {
              payload['order'] = (data['order'] as List)
                  .map((e) => e.toString())
                  .toList();
            }
            if (data['seconds'] is num) {
              payload['seconds'] = (data['seconds'] as num).toInt();
            }
            onLobbyState!(payload);
          }
          break;
        case 'ready_update':
        case 'color_update':
          if (onLobbyCommand != null) {
            final payload = Map<String, dynamic>.from(data)
              ..remove('type')
              ..remove('roomId')
              ..remove('playerId');
            onLobbyCommand!(data['playerId'], payload);
          }
          break;
        case 'chat':
          if (onChatMessage != null) {
            final messageText = data['message']?.toString() ?? '';
            if (messageText.isNotEmpty) {
              onChatMessage!(data['playerId'], messageText);
            }
          }
          break;
        case 'countdown':
          if (onCountdown != null) {
            final seconds = data['seconds'] is num
                ? (data['seconds'] as num).toInt()
                : -1;
            onCountdown!(seconds);
          }
          break;
        case 'start_game':
          onStartGame?.call();
          break;
      }
    } catch (e) {
      if (onError != null) onError!(e.toString());
    }
  }
}

String _generateRoomCode({int length = 6}) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(length, (_) => alphabet[random.nextInt(alphabet.length)])
      .join();
}
