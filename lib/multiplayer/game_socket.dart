import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';

import '../game/state/game_state.dart';

const _defaultWsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://10.0.2.2:8083',
);

class GameSocket {
  final String playerId;
  final String roomId;
  final String _endpoint;
  WebSocketChannel? _channel;
  Function(GameState)? onStateUpdate;
  Function(String, String)? onPlayerJoined;
  Function(String)? onPlayerLeft;
  Function(String)? onError;
  Function(String, Map<String, dynamic>)? onActionRequest;
  Function(String, List<String>)? onTurnUpdate;

  GameSocket({String? roomId, String? endpoint})
      : playerId = const Uuid().v4(),
        roomId = roomId ?? _generateRoomCode(),
        _endpoint = endpoint ?? _defaultWsUrl;

  bool get isConnected => _channel != null;

  Future<bool> connect() async {
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

  void sendTurnInfo(String currentId, List<String> players) {
    if (!isConnected) return;
    _sendMessage({
      'type': 'turn_update',
      'playerId': playerId,
      'roomId': roomId,
      'currentPlayerId': currentId,
      'players': players,
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
            final currentId = data['currentPlayerId']?.toString() ?? '';
            onTurnUpdate!(currentId, players);
          }
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
