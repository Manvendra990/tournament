const { pool } = require("../config/db");
const { ApiError, asyncHandler, ok } = require("../utils/http");

function validId(value) {
  const id = Number(value);

  if (!Number.isSafeInteger(id) || id < 1) {
    throw new ApiError(400, "Valid ID required");
  }

  return id;
}

function validFieldname(value) {
  if (typeof value !== "string" || !value.trim()) {
    throw new ApiError(400, "fieldname is required");
  }

  const fieldname = value.trim();

  if (fieldname.length > 150) {
    throw new ApiError(
      400,
      "fieldname must be 150 characters or fewer"
    );
  }

  return fieldname;
}

const create = asyncHandler(async (req, res) => {
  const fieldname = validFieldname(req.body.fieldname);

  const [result] = await pool.query(
    "INSERT INTO ground_fieldname (fieldname) VALUES (?)",
    [fieldname]
  );

  ok(res, { id: result.insertId, fieldname }, "Created", 201);
});

const list = asyncHandler(async (_req, res) => {
  const [rows] = await pool.query(
    "SELECT id, fieldname FROM ground_fieldname ORDER BY fieldname ASC"
  );

  ok(res, rows);
});

const getOne = asyncHandler(async (req, res) => {
  const id = validId(req.params.id);

  const [rows] = await pool.query(
    "SELECT id, fieldname FROM ground_fieldname WHERE id = ? LIMIT 1",
    [id]
  );

  if (!rows.length) {
    throw new ApiError(404, "Record not found");
  }

  ok(res, rows[0]);
});

const update = asyncHandler(async (req, res) => {
  const id = validId(req.params.id);
  const fieldname = validFieldname(req.body.fieldname);

  const [result] = await pool.query(
    "UPDATE ground_fieldname SET fieldname = ? WHERE id = ?",
    [fieldname, id]
  );

  if (!result.affectedRows) {
    throw new ApiError(404, "Record not found");
  }

  ok(res, { id, fieldname }, "Updated");
});

module.exports = { create, list, getOne, update };