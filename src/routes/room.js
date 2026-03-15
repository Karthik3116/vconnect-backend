const { Router } = require("express");
const store = require("../store/roomStore");
const { validateRoomCode, requireJson } = require("../middleware/validate");

const router = Router();

// POST /api/room/create
router.post("/create", (_req, res) => {
  const code = store.createRoom();
  res.status(201).json({ roomCode: code });
});

// POST /api/room/join
router.post("/join", requireJson, (req, res) => {
  const { roomCode } = req.body;

  if (!validateRoomCode(roomCode)) {
    return res.status(400).json({ error: "Invalid room code. Must be a 6-digit string." });
  }

  const result = store.joinRoom(roomCode);
  if (!result.ok) {
    const status = result.reason === "Room not found" ? 404 : 409;
    return res.status(status).json({ error: result.reason });
  }

  res.json({ message: "Joined room successfully", roomCode });
});

// POST /api/room/leave
router.post("/leave", requireJson, (req, res) => {
  const { roomCode } = req.body;

  if (!validateRoomCode(roomCode)) {
    return res.status(400).json({ error: "Invalid room code. Must be a 6-digit string." });
  }

  const result = store.leaveRoom(roomCode);
  if (!result.ok) {
    return res.status(404).json({ error: result.reason });
  }

  res.json({ message: "Left room successfully", roomCode, players: result.players });
});

// DELETE /api/room/:roomCode
router.delete("/:roomCode", (req, res) => {
  const { roomCode } = req.params;

  if (!validateRoomCode(roomCode)) {
    return res.status(400).json({ error: "Invalid room code. Must be a 6-digit string." });
  }

  const deleted = store.deleteRoom(roomCode);
  if (!deleted) {
    return res.status(404).json({ error: "Room not found." });
  }

  res.json({ message: "Room deleted", roomCode });
});

module.exports = router;
