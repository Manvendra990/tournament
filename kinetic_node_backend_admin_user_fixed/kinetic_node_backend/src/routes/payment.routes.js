const r = require("express").Router();
const c = require("../controllers/payment.controller");
const { authenticate, authorize } = require("../middleware/auth");

r.use(authenticate);
r.get("/mine", authorize("user"), c.listMine);

module.exports = r;
