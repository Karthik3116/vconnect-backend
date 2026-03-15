// Reusable validation helpers for request payloads.

function validateRoomCode(code) {
  return typeof code === "string" && /^\d{6}$/.test(code);
}

function validateStroke(stroke) {
  if (typeof stroke !== "object" || stroke === null) return false;
  if (typeof stroke.x !== "number" || typeof stroke.y !== "number") return false;
  if (typeof stroke.color !== "string" || stroke.color.length === 0) return false;
  if (typeof stroke.action !== "string" || stroke.action.length === 0) return false;
  if (stroke.strokeWidth !== undefined && typeof stroke.strokeWidth !== "number") return false;
  return true;
}

function requireJson(req, res, next) {
  if (!req.is("application/json")) {
    return res.status(415).json({ error: "Content-Type must be application/json" });
  }
  next();
}

module.exports = { validateRoomCode, validateStroke, requireJson };
