const { pool } = require("../config/db");
const { asyncHandler, ok } = require("../utils/http");

const listMine = asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT p.*, b.ground_id, b.ground_name, b.slot_id, b.booking_date,
            b.start_time, b.end_time, b.payment_status booking_payment_status
     FROM payments p
     JOIN bookings b ON b.id=p.booking_id
     WHERE p.user_id=?
     ORDER BY p.created_at DESC`,
    [req.user.id],
  );

  return ok(
    res,
    rows.map((r) => ({
      id: String(r.id),
      transactionId: String(r.id),
      bookingId: String(r.booking_id),
      userId: String(r.user_id),
      groundId: String(r.ground_id),
      groundName: r.ground_name,
      slotId: String(r.slot_id),
      date: r.booking_date,
      amount: Number(r.amount),
      paymentMethod: r.provider,
      paymentStatus: r.status === "paid" ? "success" : r.status,
      transactionType: r.status === "refunded" ? "refund" : "booking_payment",
      providerPaymentId: r.provider_payment_id || "",
      createdAt: r.created_at,
      paidAt: r.created_at,
    })),
  );
});

module.exports = { listMine };
