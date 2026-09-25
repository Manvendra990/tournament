const r = require("express").Router();
const c = require("../controllers/booking.controller");
const { authenticate, authorize } = require("../middleware/auth");
r.use(authenticate);
r.get("/mine", c.listMine);
r.get("/admin", authorize("admin", "superadmin"), c.listAdmin);
r.post("/", authorize("user"), c.create);
r.patch("/:id/cancel", c.cancel);
module.exports = r;
