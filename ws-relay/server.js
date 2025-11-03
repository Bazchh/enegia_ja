import { WebSocketServer } from 'ws';

     const rooms = new Map(); // roomId -> Map(playerId -> ws)

     const wss = new WebSocketServer({ port: 8083 });
     console.log('Servidor WS escutando na porta 8080');

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

         switch (data.type) {
           case 'join':
             roomId = data.roomId;
             playerId = data.playerId;
             if (!rooms.has(roomId)) {
               rooms.set(roomId, new Map());
             }
             rooms.get(roomId).set(playerId, ws);
             broadcast(roomId, { type: 'join', playerId, roomId }, playerId);
             break;

           case 'state_update':
             if (!roomId) return;
             broadcast(roomId, data, playerId);
             break;

           case 'leave':
             cleanup(roomId, playerId);
             broadcast(roomId, data, playerId);
             break;
         }
       });

       ws.on('close', () => cleanup(roomId, playerId));
     });

     function broadcast(roomId, message, senderId) {
       const room = rooms.get(roomId);
       if (!room) return;
       for (const [pid, socket] of room.entries()) {
         if (pid === senderId) continue;
         if (socket.readyState === socket.OPEN) {
           socket.send(JSON.stringify(message));
         }
       }
     }

     function cleanup(roomId, playerId) {
       if (!roomId || !playerId) return;
       const room = rooms.get(roomId);
       if (!room) return;
       room.delete(playerId);
       if (room.size === 0) rooms.delete(roomId);
     }