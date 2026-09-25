const r = require("express").Router();
const c = require("../controllers/auth.controller");
const { validate } = require("../middleware/validate");
const { authenticate } = require("../middleware/auth");

// Existing admin/email auth routes remain unchanged.
r.post("/register", validate(c.registerSchema), c.register);
r.post("/login", validate(c.loginSchema), c.login);
r.get("/me", authenticate, c.me);

// User-panel username/phone + password auth.
// Separate routes ensure existing admin auth APIs stay unchanged.
r.post("/user/register", validate(c.userRegisterSchema), c.userRegister);
r.post("/user/login", validate(c.userLoginSchema), c.userLogin);

// Legacy user-panel auth routes are retained for compatibility.
r.post("/google", c.googleLogin);
r.post("/otp/request", c.requestOtp);
r.post("/otp/verify", c.verifyOtp);

module.exports = r;
