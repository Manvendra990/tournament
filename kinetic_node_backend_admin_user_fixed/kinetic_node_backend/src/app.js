const path = require("path");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");
const env = require("./config/env");
const { notFound, errorHandler } = require("./middleware/error");
const app = express();
app.use(helmet({ crossOriginResourcePolicy: { policy: "cross-origin" } }));
app.use(
  cors({
    origin:
      env.corsOrigin === "*"
        ? true
        : env.corsOrigin.split(",").map((x) => x.trim()),
    credentials: true,
  }),
);
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(env.nodeEnv === "production" ? "combined" : "dev"));
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    limit: 180,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);
app.use("/uploads", express.static(path.join(process.cwd(), "uploads")));
app.get("/health", (_req, res) =>
  res.json({ success: true, message: "Kinetic API is running" }),
);
app.use("/api/v1/auth", require("./routes/auth.routes"));
app.use("/api/v1/profile", require("./routes/profile.routes"));
app.use("/api/v1/grounds", require("./routes/ground.routes"));
app.use("/api/v1/slots", require("./routes/slot.routes"));
app.use("/api/v1/bookings", require("./routes/booking.routes"));
app.use("/api/v1/payments", require("./routes/payment.routes"));
app.use("/api/v1/dashboard", require("./routes/dashboard.routes"));
app.use("/api/v1/admin", require("./routes/admin.routes"));
app.use("/api/v1/ground_fieldname",require("./routes/ground_fieldname.routes"));
app.use(notFound);
app.use(errorHandler);
module.exports = app;
