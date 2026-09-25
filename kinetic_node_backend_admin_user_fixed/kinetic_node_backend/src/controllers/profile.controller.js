const path = require("path");
const bcrypt = require("bcryptjs");
const { pool } = require("../config/db");
const env = require("../config/env");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const { user: userJson } = require("../utils/serializers");

const getProfile = asyncHandler(async (req, res) =>
  ok(res, { user: userJson(req.user) }),
);
const updateProfile = asyncHandler(async (req, res) => {
  const { name, phone, bio } = req.body;
  const photoUrl = req.file
    ? `${env.apiBaseUrl}/uploads/profiles/${path.basename(req.file.path)}`
    : undefined;
  const sets = [],
    values = [];
  for (const [col, val] of [
    ["name", name],
    ["phone", phone],
    ["bio", bio],
    ["photo_url", photoUrl],
  ])
    if (val !== undefined) {
      sets.push(`${col} = ?`);
      values.push(val);
    }
  if (!sets.length) throw new ApiError(422, "Nothing to update");
  values.push(req.user.id);
  await pool.query(`UPDATE users SET ${sets.join(", ")} WHERE id = ?`, values);
  const [rows] = await pool.query("SELECT * FROM users WHERE id = ?", [
    req.user.id,
  ]);
  return ok(res, { user: userJson(rows[0]) }, "Profile updated");
});
const changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword || newPassword.length < 6)
    throw new ApiError(
      422,
      "Current password and a new password of at least 6 characters are required",
    );
  if (
    !req.user.password_hash ||
    !(await bcrypt.compare(currentPassword, req.user.password_hash))
  )
    throw new ApiError(400, "Current password is incorrect");
  await pool.query("UPDATE users SET password_hash = ? WHERE id = ?", [
    await bcrypt.hash(newPassword, 12),
    req.user.id,
  ]);
  return ok(res, null, "Password changed");
});
module.exports = { getProfile, updateProfile, changePassword };
