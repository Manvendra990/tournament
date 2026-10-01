const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const env = require("./config/env");
const { pool, pingDb, ensureRuntimeSchema } = require("./config/db");
const { configureSockets } = require("./sockets");

async function start() {
  await pingDb();
  await ensureRuntimeSchema();

  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: env.corsOrigin === "*" ? true : env.corsOrigin.split(",") },
  });
  configureSockets(io);
  app.set("io", io);

  let shuttingDown = false;
  function shutdown(signal) {
    if (shuttingDown) return;
    shuttingDown = true;
    console.log(`Received ${signal}; closing API server...`);

    io.close(async () => {
      try {
        await pool.end();
      } catch (error) {
        console.error("Failed to close database pool:", error);
      }

      if (signal === "SIGUSR2") {
        process.kill(process.pid, signal);
      } else {
        process.exit(signal === "SIGINT" ? 130 : 0);
      }
    });
  }

  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP", "SIGUSR2"]) {
    process.once(signal, () => shutdown(signal));
  }

  server.listen(env.port, () => {
    console.log(`API running at ${env.apiBaseUrl}`);
    console.log(`Health check: ${env.apiBaseUrl}/health`);
    console.log('Admin login: POST /api/v1/auth/login');
    console.log('User login:  POST /api/v1/auth/user/login');
  });
}

start().catch((e) => {
  console.error("Failed to start API:", e);
  process.exit(1);
});
