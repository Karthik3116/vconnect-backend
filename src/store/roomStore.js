// In-memory store for rooms and their stroke data.
// Each room is keyed by a 6-digit code and holds player info + an ordered stroke list.

const rooms = new Map();

const MAX_ROOM_IDLE_MS = 24 * 60 * 60 * 1000; // 24 hours of inactivity
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
  const now = Date.now();
  rooms.set(code, {
    code,
    players: 1,
    strokes: [],
    createdAt: now,
    lastActivity: now,
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
  room.lastActivity = Date.now();
  return { ok: true };
}

function leaveRoom(code) {
  const room = rooms.get(code);
  if (!room) return { ok: false, reason: "Room not found" };
  if (room.players <= 0) return { ok: false, reason: "Room is already empty" };

  room.players -= 1;
  room.lastActivity = Date.now();
  return { ok: true, players: room.players };
}

function deleteRoom(code) {
  if (!rooms.has(code)) return false;
  rooms.delete(code);
  return true;
}

function addStrokes(code, strokes, strokeId, userId) {
  const room = rooms.get(code);
  if (!room) return null;

  const now = Date.now();
  const stamped = strokes.map((s) => ({
    x: s.x,
    y: s.y,
    color: s.color,
    action: s.action,
    strokeWidth: typeof s.strokeWidth === "number" ? s.strokeWidth : 8.0,
    strokeId: strokeId || null,
    userId: userId || null,
    deleted: false,
    timestamp: now,
  }));

  room.strokes.push(...stamped);
  room.lastActivity = now;
  return stamped;
}

function undoStroke(code, strokeId) {
  const room = rooms.get(code);
  if (!room) return { ok: false, reason: "Room not found" };

  // If no strokeId provided, find the most recent one
  if (!strokeId) {
    for (let i = room.strokes.length - 1; i >= 0; i--) {
      if (!room.strokes[i].deleted && room.strokes[i].strokeId) {
        strokeId = room.strokes[i].strokeId;
        break;
      }
    }
    if (!strokeId) return { ok: false, reason: "No strokes to undo" };
  }

  let count = 0;
  for (const s of room.strokes) {
    if (s.strokeId === strokeId && !s.deleted) {
      s.deleted = true;
      count++;
    }
  }

  if (count === 0) return { ok: false, reason: "Stroke not found" };

  room.lastActivity = Date.now();
  return { ok: true, strokeId, undoneCount: count };
}

function getStrokesSince(code, since) {
  const room = rooms.get(code);
  if (!room) return null;
  return room.strokes.filter((s) => s.timestamp > since && !s.deleted);
}

// Periodic cleanup of idle rooms (no activity for 24h)
function pruneStaleRooms() {
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (now - room.lastActivity > MAX_ROOM_IDLE_MS) {
      rooms.delete(code);
    }
  }
}

setInterval(pruneStaleRooms, 60 * 60 * 1000); // run every hour

module.exports = {
  createRoom,
  getRoom,
  joinRoom,
  leaveRoom,
  deleteRoom,
  addStrokes,
  undoStroke,
  getStrokesSince,
};
