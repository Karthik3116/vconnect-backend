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
    return res.status(404).json({ error: result.reason });
  }

  res.json({ message: "Joined room successfully", roomCode });
});

module.exports = router;
