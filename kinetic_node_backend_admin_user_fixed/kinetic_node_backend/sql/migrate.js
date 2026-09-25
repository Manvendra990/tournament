const mysql = require("mysql2/promise");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function migrate() {
  let connection;
  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || "localhost",
      port: Number(process.env.DB_PORT || 3306),
      user: process.env.DB_USER || "root",
      password: process.env.DB_PASSWORD || "",
      multipleStatements: true,
    });

    console.log("MySQL connected");
    const sqlPath = path.join(__dirname, "schema.sql");
    console.log("Reading schema from:", sqlPath);
    const sql = fs.readFileSync(sqlPath, "utf8");
    await connection.query(sql);

    // Safe incremental migration for databases created before username login.
    const dbName = process.env.DB_NAME || "kinetic_booking";
    const [usernameColumns] = await connection.query(
      `SELECT COLUMN_NAME FROM information_schema.COLUMNS
       WHERE TABLE_SCHEMA=? AND TABLE_NAME='users' AND COLUMN_NAME='username'`,
      [dbName],
    );
    if (!usernameColumns.length) {
      await connection.query(
        `ALTER TABLE \`${dbName}\`.users
         ADD COLUMN username VARCHAR(80) NULL AFTER name`,
      );
      console.log("Added users.username column.");
    }

    const [usernameIndexes] = await connection.query(
      `SELECT INDEX_NAME FROM information_schema.STATISTICS
       WHERE TABLE_SCHEMA=? AND TABLE_NAME='users' AND INDEX_NAME='uq_users_username'`,
      [dbName],
    );
    if (!usernameIndexes.length) {
      await connection.query(
        `ALTER TABLE \`${dbName}\`.users
         ADD UNIQUE KEY uq_users_username (username)`,
      );
      console.log("Added unique username index.");
    }

    console.log("Database and schema created/updated successfully.");
  } catch (error) {
    console.error("Migration error:", error);
    process.exitCode = 1;
  } finally {
    if (connection) await connection.end();
  }
}

migrate();
