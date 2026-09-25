const path = require('path');
const multer = require('multer');
const env = require('../config/env');
const { ApiError } = require('../utils/http');

function uploader(folder) {
  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, path.join(process.cwd(), 'uploads', folder)),
    filename: (_req, file, cb) => cb(null, `${Date.now()}-${Math.round(Math.random()*1e9)}${path.extname(file.originalname).toLowerCase()}`),
  });
  return multer({
    storage,
    limits: { fileSize: env.uploadMaxMb * 1024 * 1024 },
    fileFilter: (_req, file, cb) => file.mimetype.startsWith('image/') ? cb(null, true) : cb(new ApiError(415, 'Only image uploads are allowed')),
  });
}
module.exports = { groundUpload: uploader('grounds'), profileUpload: uploader('profiles') };
