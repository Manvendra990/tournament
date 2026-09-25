const r = require("express").Router();
const c = require("../controllers/dashboard.controller");
const { authenticate, authorize } = require("../middleware/auth");
r.use(authenticate, authorize("admin", "superadmin"));
r.get("/stats", c.stats);
r.get("/revenue", c.revenue);
module.exports = r;
