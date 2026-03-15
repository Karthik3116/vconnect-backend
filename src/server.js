const express = require("express");
const cors = require("cors");
const helmet = require("helmet");

const roomRouter = require("./routes/room");
const drawingRouter = require("./routes/drawing");

const app = express();
const PORT = process.env.PORT || 3000;

// --------------- Middleware ---------------
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "1mb" }));

// --------------- Routes ---------------
app.use("/api/room", roomRouter);
app.use("/api/drawing", drawingRouter);

// Health check
app.get("/health", (_req, res) => {
  res.json({ status: "ok", uptime: process.uptime() });
});

// 404 catch-all
app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Global error handler
app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ error: "Internal server error" });
});

// --------------- Start ---------------
app.listen(PORT, () => {
  console.log(`vconnect-backend listening on port ${PORT}`);
});

module.exports = app;
