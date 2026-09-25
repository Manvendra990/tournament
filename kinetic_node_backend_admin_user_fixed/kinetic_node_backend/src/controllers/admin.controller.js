const { pool } = require("../config/db");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const { user: userJson } = require("../utils/serializers");
const listUsers = asyncHandler(async (req, res) => {
  const [r] = await pool.query("SELECT * FROM users ORDER BY created_at DESC");
  return ok(res, r.map(userJson));
});
const setStatus = asyncHandler(async (req, res) => {
  const { status } = req.body;
  if (!["pending", "active", "suspended"].includes(status))
    throw new ApiError(422, "Invalid status");
  const [r] = await pool.query("UPDATE users SET status=? WHERE id=?", [
    status,
    req.params.id,
  ]);
  if (!r.affectedRows) throw new ApiError(404, "User not found");
  return ok(res, null, "User status updated");
});
module.exports = { listUsers, setStatus };
