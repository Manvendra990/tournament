const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { z } = require("zod");
const env = require("../config/env");
const { pool } = require("../config/db");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const { user: userJson } = require("../utils/serializers");

const registerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2),
    email: z.string().email(),
    phone: z.string().trim().min(6).max(30),
    password: z.string().min(6),
    role: z.enum(["user", "admin"]).optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

const loginSchema = z.object({
  body: z.object({ email: z.string().email(), password: z.string().min(1) }),
  params: z.object({}),
  query: z.object({}),
});


// User-panel username/phone + password registration.
// Kept separate from the existing admin /auth/register API.
const userRegisterSchema = z.object({
  body: z.object({
    username: z
      .string()
      .trim()
      .min(3)
      .max(40)
      .regex(/^[A-Za-z0-9_.]+$/, "Username can contain only letters, numbers, _ and ."),
    phone: z.string().trim().min(6).max(30),
    password: z.string().min(6).max(100),
  }),
  params: z.object({}),
  query: z.object({}),
});

const userLoginSchema = z.object({
  body: z.object({
    identifier: z.string().trim().min(1),
    password: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

const userRegister = asyncHandler(async (req, res) => {
  const username = req.validated.body.username.trim();
  const phone = req.validated.body.phone.trim();
  const password = req.validated.body.password;

  const [existing] = await pool.query(
    `SELECT id FROM users
     WHERE LOWER(username)=LOWER(?) OR phone=?
     LIMIT 1`,
    [username, phone],
  );

  if (existing.length)
    throw new ApiError(409, "Username or phone number is already registered");

  const passwordHash = await bcrypt.hash(password, 12);
  const [result] = await pool.query(
    `INSERT INTO users
      (name, username, phone, password_hash, role, status)
     VALUES (?, ?, ?, ?, 'user', 'active')`,
    [username, username, phone, passwordHash],
  );

  const [rows] = await pool.query("SELECT * FROM users WHERE id=?", [
    result.insertId,
  ]);
  const user = rows[0];

  return ok(
    res,
    { token: tokenFor(user), user: userJson(user), role: user.role },
    "Registration successful",
    201,
  );
});

const userLogin = asyncHandler(async (req, res) => {
  const identifier = req.validated.body.identifier.trim();
  const password = req.validated.body.password;

  const [rows] = await pool.query(
    `SELECT * FROM users
     WHERE role='user'
       AND (LOWER(username)=LOWER(?) OR phone=?)
     LIMIT 1`,
    [identifier, identifier],
  );

  const user = rows[0];
  if (
    !user ||
    !user.password_hash ||
    !(await bcrypt.compare(password, user.password_hash))
  ) {
    throw new ApiError(401, "Invalid username/phone or password");
  }

  if (user.status === "suspended")
    throw new ApiError(403, "Your account has been suspended. Contact support.");
  if (user.status === "pending")
    throw new ApiError(403, "Your account is pending approval.");

  return ok(
    res,
    { token: tokenFor(user), user: userJson(user), role: user.role },
    "Login successful",
  );
});

function tokenFor(user) {
  return jwt.sign({ sub: String(user.id), role: user.role }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

const register = asyncHandler(async (req, res) => {
  const { name, email, phone, password } = req.validated.body;
  const role = req.validated.body.role || "admin";
  const [existing] = await pool.query(
    "SELECT id FROM users WHERE email = ? OR phone = ? LIMIT 1",
    [email.toLowerCase(), phone],
  );
  if (existing.length)
    throw new ApiError(409, "Email or phone is already registered");

  const passwordHash = await bcrypt.hash(password, 12);
  const status = role === "admin" ? env.adminRegistrationStatus : "active";
  const [result] = await pool.query(
    "INSERT INTO users (name,email,phone,password_hash,role,status) VALUES (?,?,?,?,?,?)",
    [name, email.toLowerCase(), phone, passwordHash, role, status],
  );
  const [rows] = await pool.query("SELECT * FROM users WHERE id = ?", [
    result.insertId,
  ]);
  return ok(
    res,
    {
      user: userJson(rows[0]),
      token: status === "active" ? tokenFor(rows[0]) : null,
    },
    status === "active"
      ? "Registration successful"
      : "Registration submitted for approval",
    201,
  );
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.validated.body;
  const [rows] = await pool.query(
    "SELECT * FROM users WHERE email = ? LIMIT 1",
    [email.toLowerCase()],
  );
  const user = rows[0];
  if (
    !user ||
    !user.password_hash ||
    !(await bcrypt.compare(password, user.password_hash))
  )
    throw new ApiError(401, "Invalid email or password");
  if (user.status === "suspended")
    throw new ApiError(
      403,
      "Your account has been suspended. Contact support.",
    );
  if (user.status === "pending")
    throw new ApiError(403, "Your account is pending Super Admin approval.");

  return ok(
    res,
    { token: tokenFor(user), user: userJson(user), role: user.role },
    "Login successful",
  );
});

// User panel Google sign-in. Existing email/password admin APIs are untouched.
const googleLogin = asyncHandler(async (req, res) => {
  const idToken = String(req.body.idToken || "").trim();
  if (!idToken) throw new ApiError(422, "idToken is required");

  // Verify the Google ID token with Google's tokeninfo endpoint.
  const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
  let google;
  try {
    const response = await fetch(verifyUrl);
    if (!response.ok) throw new Error("invalid google token");
    google = await response.json();
  } catch (_) {
    throw new ApiError(401, "Invalid Google sign-in token");
  }

  if (env.googleClientId && String(google.aud || "") !== env.googleClientId) {
    throw new ApiError(401, "Google token audience does not match this app");
  }

  const email = String(google.email || "").toLowerCase().trim();
  const googleId = String(google.sub || "").trim();
  const name = String(google.name || google.given_name || "Player").trim();
  const photo = String(google.picture || "").trim();
  const emailVerified = String(google.email_verified || "true") === "true";

  if (!email || !googleId || !emailVerified)
    throw new ApiError(401, "Google account email could not be verified");

  let [rows] = await pool.query(
    "SELECT * FROM users WHERE email=? OR firebase_uid=? LIMIT 1",
    [email, `google:${googleId}`],
  );
  let user = rows[0];

  if (!user) {
    const [result] = await pool.query(
      `INSERT INTO users (name,email,role,status,photo_url,firebase_uid)
       VALUES (?,?,'user','active',?,?)`,
      [name || "Player", email, photo || null, `google:${googleId}`],
    );
    [rows] = await pool.query("SELECT * FROM users WHERE id=?", [result.insertId]);
    user = rows[0];
  } else {
    if (user.status !== "active")
      throw new ApiError(403, `Account is ${user.status}`);
    await pool.query(
      `UPDATE users
       SET name=COALESCE(NULLIF(?,''),name),
           photo_url=COALESCE(NULLIF(?,''),photo_url),
           firebase_uid=COALESCE(firebase_uid,?)
       WHERE id=?`,
      [name, photo, `google:${googleId}`, user.id],
    );
    [rows] = await pool.query("SELECT * FROM users WHERE id=?", [user.id]);
    user = rows[0];
  }

  if (user.role !== "user")
    throw new ApiError(403, "Please use the admin panel for this account");

  return ok(
    res,
    { token: tokenFor(user), user: userJson(user), role: user.role },
    "Google sign-in successful",
  );
});

// Development-friendly phone OTP API replacing Firebase phone auth.
// Hook sendOtpToProvider() to your SMS provider before production deployment.
async function sendOtpToProvider(_phone, _otp) {
  return true;
}

const requestOtp = asyncHandler(async (req, res) => {
  const phone = String(req.body.phone || "").trim();
  if (phone.length < 6) throw new ApiError(422, "Valid phone is required");

  const otp = String(crypto.randomInt(100000, 1000000));
  const otpHash = await bcrypt.hash(otp, 8);

  await pool.query("DELETE FROM user_otps WHERE phone=?", [phone]);
  await pool.query(
    `INSERT INTO user_otps (phone,otp_hash,expires_at)
     VALUES (?,?,DATE_ADD(NOW(), INTERVAL 5 MINUTE))`,
    [phone, otpHash],
  );

  await sendOtpToProvider(phone, otp);

  const data = { sent: true };
  if (env.nodeEnv !== "production") data.devOtp = otp;
  return ok(res, data, "OTP sent");
});

const verifyOtp = asyncHandler(async (req, res) => {
  const phone = String(req.body.phone || "").trim();
  const otp = String(req.body.otp || "").trim();
  if (!phone || otp.length !== 6)
    throw new ApiError(422, "phone and 6-digit otp are required");

  const [otpRows] = await pool.query(
    `SELECT * FROM user_otps
     WHERE phone=? AND used_at IS NULL AND expires_at>NOW()
     ORDER BY id DESC LIMIT 1`,
    [phone],
  );
  const record = otpRows[0];
  if (!record || !(await bcrypt.compare(otp, record.otp_hash)))
    throw new ApiError(401, "Invalid or expired OTP");

  await pool.query("UPDATE user_otps SET used_at=NOW() WHERE id=?", [record.id]);

  let [rows] = await pool.query("SELECT * FROM users WHERE phone=? LIMIT 1", [phone]);
  let user = rows[0];
  if (!user) {
    const [result] = await pool.query(
      `INSERT INTO users (name,phone,role,status)
       VALUES (? ,?,'user','active')`,
      ["Player", phone],
    );
    [rows] = await pool.query("SELECT * FROM users WHERE id=?", [result.insertId]);
    user = rows[0];
  }
  if (user.status !== "active") throw new ApiError(403, `Account is ${user.status}`);
  if (user.role !== "user")
    throw new ApiError(403, "Please use the admin panel for this account");

  return ok(
    res,
    { token: tokenFor(user), user: userJson(user), role: user.role },
    "Phone sign-in successful",
  );
});

const me = asyncHandler(async (req, res) =>
  ok(res, { user: userJson(req.user) }),
);

module.exports = {
  registerSchema,
  loginSchema,
  userRegisterSchema,
  userLoginSchema,
  register,
  login,
  userRegister,
  userLogin,
  googleLogin,
  requestOtp,
  verifyOtp,
  me,
};
