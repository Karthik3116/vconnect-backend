const { Router } = require("express");
const store = require("../store/roomStore");
const {
  validateRoomCode,
  validateStroke,
  requireJson,
} = require("../middleware/validate");

const router = Router();

// POST /api/drawing/submit
router.post("/submit", requireJson, (req, res) => {
  const { roomCode, strokes } = req.body;

  if (!validateRoomCode(roomCode)) {
    return res
      .status(400)
      .json({ error: "Invalid room code. Must be a 6-digit string." });
  }

  if (!Array.isArray(strokes) || strokes.length === 0) {
    return res
      .status(400)
      .json({ error: "strokes must be a non-empty array." });
  }

  for (let i = 0; i < strokes.length; i++) {
    if (!validateStroke(strokes[i])) {
      return res.status(400).json({
        error: `Invalid stroke at index ${i}. Each stroke needs numeric x, y and string color, action.`,
      });
    }
  }

  const saved = store.addStrokes(roomCode, strokes);
  if (!saved) {
    return res.status(404).json({ error: "Room not found." });
  }

  res.json({ message: "Strokes saved", count: saved.length });
});

// GET /api/drawing/sync/:roomCode?last_timestamp=<time>
router.get("/sync/:roomCode", (req, res) => {
  const { roomCode } = req.params;

  if (!validateRoomCode(roomCode)) {
    return res
      .status(400)
      .json({ error: "Invalid room code. Must be a 6-digit string." });
  }

  const since = Number(req.query.last_timestamp) || 0;

  const newStrokes = store.getStrokesSince(roomCode, since);
  if (newStrokes === null) {
    return res.status(404).json({ error: "Room not found." });
  }

  res.json({
    strokes: newStrokes,
    count: newStrokes.length,
    serverTime: Date.now(),
  });
});

module.exports = router;
