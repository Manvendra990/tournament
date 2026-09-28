const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { pool } = require('../config/db');
const { ApiError, asyncHandler } = require('../utils/http');

const authenticate = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new ApiError(401, 'Authentication required');
  let payload;
  try { payload = jwt.verify(token, env.jwtSecret); } catch { throw new ApiError(401, 'Invalid or expired token'); }
  const [rows] = await pool.query('SELECT * FROM users WHERE id = ? LIMIT 1', [payload.sub]);
  const user = rows[0];
  if (!user) throw new ApiError(401, 'Account not found');
  if (user.status !== 'active') throw new ApiError(403, `Account is ${user.status}`);
  req.user = user;
  next();
});

const authorize = (...roles) => (req, _res, next) => {
  if (!req.user || !roles.includes(req.user.role)) return next(new ApiError(403, 'You do not have permission for this action'));
  next();
};
module.exports = { authenticate, authorize };

