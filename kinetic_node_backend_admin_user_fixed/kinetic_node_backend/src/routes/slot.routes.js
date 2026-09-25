const r = require("express").Router();
const c = require("../controllers/slot.controller");
const { authenticate, authorize } = require("../middleware/auth");

r.use(authenticate);

// IMPORTANT: /mine ko dynamic routes se pehle rakho
r.get(
  "/mine",
  authorize("admin", "superadmin"),
  c.mine
);

r.get("/", c.list);

r.post(
  "/",
  authorize("admin", "superadmin"),
  c.create
);

r.post(
  "/bulk",
  authorize("admin", "superadmin"),
  c.bulkCreate
);

r.patch(
  "/:id",
  authorize("admin", "superadmin"),
  c.update
);

r.delete(
  "/:id",
  authorize("admin", "superadmin"),
  c.remove
);

module.exports = r;