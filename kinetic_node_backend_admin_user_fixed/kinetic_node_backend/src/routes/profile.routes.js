const r = require("express").Router();
const c = require("../controllers/profile.controller");
const { authenticate } = require("../middleware/auth");
const { profileUpload } = require("../middleware/upload");
r.use(authenticate);
r.get("/", c.getProfile);
r.patch("/", profileUpload.single("photo"), c.updateProfile);
r.patch("/password", c.changePassword);
module.exports = r;
