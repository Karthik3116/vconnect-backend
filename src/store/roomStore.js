// In-memory store for rooms and their stroke data.
// Each room is keyed by a 6-digit code and holds player info + an ordered stroke list.

const rooms = new Map();

const MAX_ROOM_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours
const MAX_PLAYERS = 2;

function generateRoomCode() {
  let code;
  do {
    code = String(Math.floor(100000 + Math.random() * 900000));
  } while (rooms.has(code));
  return code;
}

function createRoom() {
  const code = generateRoomCode();
  rooms.set(code, {
    code,
    players: 1,
    strokes: [],
    createdAt: Date.now(),
  });
  return code;
}

function getRoom(code) {
  return rooms.get(code) || null;
}

function joinRoom(code) {
  const room = rooms.get(code);
  if (!room) return { ok: false, reason: "Room not found" };
  if (room.players >= MAX_PLAYERS)
    return { ok: false, reason: "Room is full" };

  room.players += 1;
  return { ok: true };
}

function addStrokes(code, strokes) {
  const room = rooms.get(code);
  if (!room) return null;

  const now = Date.now();
  const stamped = strokes.map((s) => ({
    x: s.x,
    y: s.y,
    color: s.color,
    action: s.action,
    timestamp: now,
  }));

  room.strokes.push(...stamped);
  return stamped;
}

function getStrokesSince(code, since) {
  const room = rooms.get(code);
  if (!room) return null;
  return room.strokes.filter((s) => s.timestamp > since);
}

// Periodic cleanup of stale rooms
function pruneStaleRooms() {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.createdAt > MAX_ROOM_AGE_MS) {
      rooms.delete(code);
    }
  }
}

setInterval(pruneStaleRooms, 60 * 60 * 1000); // run every hour

module.exports = {
  createRoom,
  getRoom,
  joinRoom,
  addStrokes,
  getStrokesSince,
};
