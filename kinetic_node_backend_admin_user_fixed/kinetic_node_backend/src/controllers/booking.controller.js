const { pool } = require("../config/db");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const S = require("../utils/serializers");

const listMine = asyncHandler(async (req, res) => {
  const [r] = await pool.query(
    "SELECT * FROM bookings WHERE user_id=? ORDER BY created_at DESC",
    [req.user.id],
  );
  return ok(res, r.map(S.booking));
});

const listAdmin = asyncHandler(async (req, res) => {
  if (!["admin", "superadmin"].includes(req.user.role))
    throw new ApiError(403, "Admin only");
  const vals = [];
  let sql = "SELECT * FROM bookings WHERE 1=1";
  if (req.user.role === "admin") {
    sql += " AND admin_id=?";
    vals.push(req.user.id);
  }
  if (req.query.from) {
    sql += " AND booking_date>=?";
    vals.push(req.query.from);
  }
  if (req.query.to) {
    sql += " AND booking_date<=?";
    vals.push(req.query.to);
  }
  if (req.query.status) {
    sql += " AND booking_status=?";
    vals.push(req.query.status);
  }
  sql += " ORDER BY created_at DESC";
  const [r] = await pool.query(sql, vals);
  return ok(res, r.map(S.booking));
});

const create = asyncHandler(async (req, res) => {
  const {
    slotId,
    paymentReference,
    paymentStatus,
    paymentMethod,
  } = req.body;
  if (!slotId) throw new ApiError(422, "slotId is required");

  const requestedPaid = paymentStatus === "paid";
  const normalizedPaymentStatus = requestedPaid ? "paid" : "pending";
  const provider = String(paymentMethod || (requestedPaid ? "cash" : "manual"));

  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    const [sr] = await c.query(
      `SELECT s.*,g.admin_id,g.name ground_name
       FROM slots s
       JOIN grounds g ON g.id=s.ground_id
       WHERE s.id=? FOR UPDATE`,
      [slotId],
    );
    const s = sr[0];
    if (!s) throw new ApiError(404, "Slot not found");
    if (s.status !== "available")
      throw new ApiError(409, "Slot is not available");

    const [br] = await c.query(
      `INSERT INTO bookings
       (user_id,admin_id,ground_id,slot_id,ground_name,booking_date,start_time,end_time,amount,payment_status,booking_status,payment_reference)
       VALUES (?,?,?,?,?,?,?,?,?,?, 'upcoming',?)`,
      [
        req.user.id,
        s.admin_id,
        s.ground_id,
        s.id,
        s.ground_name,
        s.slot_date,
        s.start_time,
        s.end_time,
        s.price,
        normalizedPaymentStatus,
        paymentReference || null,
      ],
    );

    if (requestedPaid) {
      await c.query(
        `INSERT INTO payments
         (booking_id,user_id,provider,provider_payment_id,amount,status,raw_payload)
         VALUES (?,?,?,?,?,'paid',?)`,
        [
          br.insertId,
          req.user.id,
          provider,
          paymentReference || null,
          s.price,
          JSON.stringify({ source: "user-panel", method: provider }),
        ],
      );
    }

    await c.query("UPDATE slots SET status='booked' WHERE id=?", [s.id]);
    await c.commit();

    req.app
      .get("io")
      ?.to(`admin:${s.admin_id}`)
      .emit("booking:created", { bookingId: String(br.insertId) });
    req.app.get("io")?.emit(`slots:${s.ground_id}:${s.slot_date}`, {
      type: "updated",
      slotId: String(s.id),
      status: "booked",
    });

    return ok(
      res,
      { id: String(br.insertId) },
      "Booking created",
      201,
    );
  } catch (e) {
    await c.rollback();
    throw e;
  } finally {
    c.release();
  }
});

const cancel = asyncHandler(async (req, res) => {
  const c = await pool.getConnection();
  try {
    await c.beginTransaction();
    const [rows] = await c.query(
      "SELECT * FROM bookings WHERE id=? FOR UPDATE",
      [req.params.id],
    );
    const b = rows[0];
    if (!b) throw new ApiError(404, "Booking not found");
    const allowed =
      Number(b.user_id) === Number(req.user.id) ||
      Number(b.admin_id) === Number(req.user.id) ||
      req.user.role === "superadmin";
    if (!allowed) throw new ApiError(403, "Not allowed");
    if (b.booking_status === "cancelled")
      throw new ApiError(409, "Booking already cancelled");

    await c.query(
      "UPDATE bookings SET booking_status='cancelled',cancellation_reason=? WHERE id=?",
      [req.body.reason || null, b.id],
    );
    await c.query("UPDATE slots SET status='available' WHERE id=?", [b.slot_id]);
    await c.query(
      "INSERT INTO notifications (user_id,type,title,message,metadata) VALUES (?,?,?,?,?)",
      [
        b.user_id,
        "booking_cancelled",
        "Booking cancelled",
        `Your booking at ${b.ground_name} has been cancelled.`,
        JSON.stringify({ bookingId: String(b.id) }),
      ],
    );
    await c.commit();

    req.app.get("io")?.to(`user:${b.user_id}`).emit("booking:updated", {
      bookingId: String(b.id),
      status: "cancelled",
    });
    req.app.get("io")?.to(`admin:${b.admin_id}`).emit("booking:updated", {
      bookingId: String(b.id),
      status: "cancelled",
    });
    return ok(res, null, "Booking cancelled");
  } catch (e) {
    await c.rollback();
    throw e;
  } finally {
    c.release();
  }
});

module.exports = { listMine, listAdmin, create, cancel };
