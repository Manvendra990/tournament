const r = require("express").Router();
const c = require("../controllers/admin.controller");
const { authenticate, authorize } = require("../middleware/auth");
r.use(authenticate, authorize("superadmin"));
r.get("/users", c.listUsers);
r.patch("/users/:id/status", c.setStatus);
module.exports = r;
