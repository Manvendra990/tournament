const { ApiError } = require('../utils/http');
function notFound(req, _res, next) { next(new ApiError(404, `Route not found: ${req.method} ${req.originalUrl}`)); }
function errorHandler(err, _req, res, _next) {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  const body = { success: false, message: err.message || 'Internal server error' };
  if (err.details) body.details = err.details;
  if (err.code === 'ER_DUP_ENTRY') { body.message = 'Duplicate value already exists'; return res.status(409).json(body); }
  return res.status(status).json(body);
}
module.exports = { notFound, errorHandler };
