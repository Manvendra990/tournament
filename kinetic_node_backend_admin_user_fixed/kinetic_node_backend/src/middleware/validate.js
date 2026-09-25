const { ApiError } = require('../utils/http');
const validate = (schema) => (req, _res, next) => {
  const parsed = schema.safeParse({ body: req.body, params: req.params, query: req.query });
  if (!parsed.success) return next(new ApiError(422, 'Validation failed', parsed.error.flatten()));
  req.validated = parsed.data;
  next();
};
module.exports = { validate };
