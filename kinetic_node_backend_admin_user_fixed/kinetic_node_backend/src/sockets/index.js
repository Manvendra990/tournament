const jwt = require("jsonwebtoken");
const env = require("../config/env");
function configureSockets(io) {
  io.use((socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers.authorization?.replace("Bearer ", "");
      if (!token) return next(new Error("Authentication required"));
      socket.user = jwt.verify(token, env.jwtSecret);
      next();
    } catch {
      return next(new Error("Invalid token"));
    }
  });
  io.on("connection", (socket) => {
    socket.join(`user:${socket.user.sub}`);
    if (["admin", "superadmin"].includes(socket.user.role))
      socket.join(`admin:${socket.user.sub}`);
    socket.on("slots:subscribe", ({ groundId, date }) =>
      socket.join(`slots:${groundId}:${date}`),
    );
    socket.on("slots:unsubscribe", ({ groundId, date }) =>
      socket.leave(`slots:${groundId}:${date}`),
    );
  });
}
module.exports = { configureSockets };
