const mysql = require('mysql2/promise');
const env = require('./env');

const pool = mysql.createPool({
  ...env.db,
  waitForConnections: true,
  queueLimit: 0,
  decimalNumbers: true,
  dateStrings: true,
});

async function pingDb() {
  const connection = await pool.getConnection();
  try { await connection.ping(); } finally { connection.release(); }
}

// Keeps an existing admin-only database compatible with the combined
// admin + user backend. This is intentionally additive and does not remove
// or rewrite existing admin data.
async function ensureRuntimeSchema() {
  const dbName = env.db.database;
  const connection = await pool.getConnection();
  try {
    const [usernameColumns] = await connection.query(
      `SELECT COLUMN_NAME FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA=? AND TABLE_NAME='users' AND COLUMN_NAME='username'`,
      [dbName],
    );

    if (!usernameColumns.length) {
      await connection.query(
        'ALTER TABLE users ADD COLUMN username VARCHAR(80) NULL AFTER name',
      );
      console.log('[DB] Added users.username for user-panel authentication');
    }

    const [usernameIndexes] = await connection.query(
      `SELECT INDEX_NAME FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA=? AND TABLE_NAME='users' AND INDEX_NAME='uq_users_username'`,
      [dbName],
    );

    if (!usernameIndexes.length) {
      await connection.query(
        'ALTER TABLE users ADD UNIQUE KEY uq_users_username (username)',
      );
      console.log('[DB] Added unique username index');
    }

    await connection.query(`
      CREATE TABLE IF NOT EXISTS user_otps (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        phone VARCHAR(30) NOT NULL,
        otp_hash VARCHAR(255) NOT NULL,
        expires_at DATETIME NOT NULL,
        used_at DATETIME NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY idx_user_otps_phone_expiry (phone, expires_at)
      ) ENGINE=InnoDB
    `);
  } finally {
    connection.release();
  }
}

module.exports = { pool, pingDb, ensureRuntimeSchema };
