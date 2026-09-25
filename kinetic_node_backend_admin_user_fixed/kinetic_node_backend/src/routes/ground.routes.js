const r = require("express").Router();
const c = require("../controllers/ground.controller");
const { authenticate, authorize } = require("../middleware/auth");
const { groundUpload } = require("../middleware/upload");
r.get("/public", c.listPublic);
r.get("/:id", c.getOne);
r.use(authenticate);
r.get("/", authorize("admin", "superadmin"), c.listMine);
r.post(
  "/",
  authorize("admin", "superadmin"),
  groundUpload.array("images", 10),
  c.create,
);
r.patch("/:id", authorize("admin", "superadmin"), c.update);
r.patch("/:id/status", authorize("admin", "superadmin"), c.toggleStatus);
r.post(
  "/:id/images",
  authorize("admin", "superadmin"),
  groundUpload.array("images", 10),
  c.uploadImages,
);
r.delete(
  "/:id/images/:imageId",
  authorize("admin", "superadmin"),
  c.deleteImage,
);
module.exports = r;
