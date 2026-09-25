const dotenv = require('dotenv');
dotenv.config();

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined || value === '') throw new Error(`Missing environment variable: ${name}`);
  return value;
}

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  apiBaseUrl: process.env.API_BASE_URL || `http://localhost:${process.env.PORT || 3000}`,
  corsOrigin: process.env.CORS_ORIGIN || '*',
  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'kinetic_booking',
    connectionLimit: Number(process.env.DB_CONNECTION_LIMIT || 10),
  },
  jwtSecret: required('JWT_SECRET', process.env.NODE_ENV === 'production' ? undefined : 'dev-only-change-this-secret-1234567890'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  adminRegistrationStatus: process.env.ADMIN_REGISTRATION_STATUS || 'active',
  uploadMaxMb: Number(process.env.UPLOAD_MAX_MB || 8),
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
};
