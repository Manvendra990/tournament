const { pool } = require("../config/db");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const S = require("../utils/serializers");

function normalizeMySqlTime(value) {
  if (value === null || value === undefined || value === "") return value;

  if (typeof value === "string") {
    const trimmed = value.trim();
    const timePart = trimmed.includes("T") ? trimmed.split("T")[1] : trimmed;
    const isoWithoutZone = timePart.replace(/Z$/i, "");

    const match = isoWithoutZone.match(
      /^(\d{1,2}:\d{2})(?::\d{2}(?:\.\d+)?)?$/,
    );

    if (match) {
      return `${match[1]}:00`;
    }

    const timeOnly = isoWithoutZone.match(
      /^(\d{2}:\d{2}:\d{2})(?:\.\d+)?$/,
    );

    if (timeOnly) return timeOnly[1];
  }

  return value;
}

async function assertGroundOwner(groundId, user) {
  const [r] = await pool.query(
    "SELECT admin_id FROM grounds WHERE id=?",
    [groundId],
  );

  if (!r[0]) {
    throw new ApiError(404, "Ground not found");
  }

  if (
    user.role !== "superadmin" &&
    Number(r[0].admin_id) !== Number(user.id)
  ) {
    throw new ApiError(403, "Not your ground");
  }

  return r[0];
}


// ======================================================
// GET SPECIFIC GROUND + DATE SLOTS
// ======================================================

const list = asyncHandler(async (req, res) => {
  const { groundId, date } = req.query;

  if (!groundId || !date) {
    throw new ApiError(
      422,
      "groundId and date are required",
    );
  }

  const [r] = await pool.query(
    `
    SELECT *
    FROM slots
    WHERE ground_id=?
      AND slot_date=?
    ORDER BY start_time
    `,
    [groundId, date],
  );

  return ok(
    res,
    r.map(S.slot),
  );
});


// ======================================================
// GET LOGGED-IN ADMIN ALL SLOTS
// ======================================================

const mine = asyncHandler(async (req, res) => {
  let sql = `
    SELECT s.*
    FROM slots s
    JOIN grounds g
      ON g.id = s.ground_id
  `;

  const params = [];

  if (req.user.role !== "superadmin") {
    sql += `
      WHERE g.admin_id = ?
    `;

    params.push(req.user.id);
  }

  sql += `
    ORDER BY
      s.slot_date ASC,
      s.start_time ASC
  `;

  const [rows] = await pool.query(
    sql,
    params,
  );

  return ok(
    res,
    rows.map(S.slot),
  );
});


// ======================================================
// CREATE SINGLE SLOT
// ======================================================

const create = asyncHandler(async (req, res) => {
  const b = req.body;

  await assertGroundOwner(
    b.groundId,
    req.user,
  );

  const [r] = await pool.query(
    `
    INSERT INTO slots
    (
      ground_id,
      slot_date,
      start_time,
      end_time,
      price,
      status
    )
    VALUES (?,?,?,?,?,?)
    `,
    [
      b.groundId,
      b.date,
      normalizeMySqlTime(b.startTime),
      normalizeMySqlTime(b.endTime),
      b.price || 0,
      b.status || "available",
    ],
  );

  req.app.get("io")?.emit(
    `slots:${b.groundId}:${b.date}`,
    {
      type: "created",
      slotId: String(r.insertId),
    },
  );

  return ok(
    res,
    {
      id: String(r.insertId),
    },
    "Slot created",
    201,
  );
});


// ======================================================
// BULK CREATE SLOTS
// ======================================================

const bulkCreate = asyncHandler(async (req, res) => {
  const slots = req.body.slots;

  if (
    !Array.isArray(slots) ||
    !slots.length
  ) {
    throw new ApiError(
      422,
      "slots array is required",
    );
  }

  await assertGroundOwner(
    slots[0].groundId,
    req.user,
  );

  const c = await pool.getConnection();

  try {
    await c.beginTransaction();

    for (const s of slots) {
      await c.query(
        `
        INSERT INTO slots
        (
          ground_id,
          slot_date,
          start_time,
          end_time,
          price,
          status
        )
        VALUES (?,?,?,?,?,?)
        `,
        [
          s.groundId,
          s.date,
          normalizeMySqlTime(s.startTime),
          normalizeMySqlTime(s.endTime),
          s.price || 0,
          s.status || "available",
        ],
      );
    }

    await c.commit();
  } catch (e) {
    await c.rollback();
    throw e;
  } finally {
    c.release();
  }

  req.app.get("io")?.emit(
    `slots:${slots[0].groundId}:${slots[0].date}`,
    {
      type: "bulk-created",
    },
  );

  return ok(
    res,
    {
      count: slots.length,
    },
    "Slots created",
    201,
  );
});


// ======================================================
// UPDATE SLOT
// ======================================================

const update = asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    `
    SELECT
      s.*,
      g.admin_id
    FROM slots s
    JOIN grounds g
      ON g.id = s.ground_id
    WHERE s.id=?
    `,
    [req.params.id],
  );

  if (!rows[0]) {
    throw new ApiError(
      404,
      "Slot not found",
    );
  }

  if (
    req.user.role !== "superadmin" &&
    Number(rows[0].admin_id) !== Number(req.user.id)
  ) {
    throw new ApiError(
      403,
      "Not allowed",
    );
  }

  const sets = [];
  const vals = [];

  if (req.body.status !== undefined) {
    sets.push("status=?");
    vals.push(req.body.status);
  }

  if (req.body.price !== undefined) {
    sets.push("price=?");
    vals.push(req.body.price);
  }

  if (!sets.length) {
    throw new ApiError(
      422,
      "status or price required",
    );
  }

  vals.push(req.params.id);

  await pool.query(
    `
    UPDATE slots
    SET ${sets.join(",")}
    WHERE id=?
    `,
    vals,
  );

  req.app.get("io")?.emit(
    `slots:${rows[0].ground_id}:${rows[0].slot_date}`,
    {
      type: "updated",
      slotId: String(req.params.id),
    },
  );

  return ok(
    res,
    null,
    "Slot updated",
  );
});


// ======================================================
// DELETE SLOT
// ======================================================

const remove = asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    `
    SELECT
      s.*,
      g.admin_id
    FROM slots s
    JOIN grounds g
      ON g.id = s.ground_id
    WHERE s.id=?
    `,
    [req.params.id],
  );

  if (!rows[0]) {
    throw new ApiError(
      404,
      "Slot not found",
    );
  }

  if (
    req.user.role !== "superadmin" &&
    Number(rows[0].admin_id) !== Number(req.user.id)
  ) {
    throw new ApiError(
      403,
      "Not allowed",
    );
  }

  if (rows[0].status === "booked") {
    throw new ApiError(
      409,
      "Booked slot cannot be deleted",
    );
  }

  await pool.query(
    "DELETE FROM slots WHERE id=?",
    [req.params.id],
  );

  return ok(
    res,
    null,
    "Slot deleted",
  );
});


// ======================================================
// EXPORT
// ======================================================

module.exports = {
  list,
  mine,
  create,
  bulkCreate,
  update,
  remove,
};