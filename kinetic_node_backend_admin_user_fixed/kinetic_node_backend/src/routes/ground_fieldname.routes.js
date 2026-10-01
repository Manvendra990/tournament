const router = require("express").Router();
const controller = require("../controllers/ground_fieldname.controller");
const { authenticate, authorize } = require("../middleware/auth");

router.get("/", controller.list);
router.get("/:id", controller.getOne);

router.post(
  "/",
  authenticate,
  authorize("admin", "superadmin"),
  controller.create
);

router.patch(
  "/:id",
  authenticate,
  authorize("admin", "superadmin"),
  controller.update
);

module.exports = router;