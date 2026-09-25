class ApiError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
const ok = (res, data, message = 'OK', status = 200) => res.status(status).json({ success: true, message, data });
module.exports = { ApiError, asyncHandler, ok };
