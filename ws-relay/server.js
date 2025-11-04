import { WebSocketServer } from 'ws';

const rooms = new Map(); // roomId -> Map(playerId -> ws)

const wss = new WebSocketServer({ port: 8083 });
console.log('Servidor WS escutando na porta 8083');

wss.on('connection', (ws) => {
  let roomId;
  let playerId;

  ws.on('message', (raw) => {
    let data;
    try {
      data = JSON.parse(raw);
    } catch {
      return;
    }

    const type = data.type;

    switch (type) {
      case 'join':
        roomId = data.roomId;
        playerId = data.playerId;
        if (!roomId || !playerId) {
          return;
        }
        if (!rooms.has(roomId)) {
          rooms.set(roomId, new Map());
        }
        rooms.get(roomId).set(playerId, ws);
        broadcast(roomId, { type: 'join', playerId, roomId }, playerId);
        break;

      case 'leave':
        broadcast(roomId, data, playerId);
        cleanup(roomId, playerId);
        break;

      case 'state_update':
      case 'action_request':
      case 'turn_update':
      case 'lobby_state':
      case 'ready_update':
      case 'color_update':
      case 'chat':
      case 'countdown':
      case 'start_game':
        if (!roomId) return;
        broadcast(roomId, data, playerId);
        break;

      default:
        break;
    }
  });

  ws.on('close', () => cleanup(roomId, playerId));
  ws.on('error', () => cleanup(roomId, playerId));
});

function broadcast(roomId, message, senderId) {
  const room = rooms.get(roomId);
  if (!room) return;
  const encoded = JSON.stringify(message);
  for (const [pid, socket] of room.entries()) {
    if (pid === senderId) continue;
    if (socket.readyState === socket.OPEN) {
      socket.send(encoded);
    }
  }
}

function cleanup(roomId, playerId) {
  if (!roomId || !playerId) return;
  const room = rooms.get(roomId);
  if (!room) return;
  room.delete(playerId);
  if (room.size === 0) {
    rooms.delete(roomId);
  }
}
