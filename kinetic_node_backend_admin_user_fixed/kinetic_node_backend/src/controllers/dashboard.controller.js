const { pool } = require("../config/db");
const { asyncHandler, ok } = require("../utils/http");
const stats = asyncHandler(async (req, res) => {
  const admin = req.user.id;
  const [[grounds], [today], [revenue], [upcoming]] = await Promise.all([
    pool.query("SELECT COUNT(*) count FROM grounds WHERE admin_id=?", [admin]),
    pool.query(
      "SELECT COUNT(*) count FROM bookings WHERE admin_id=? AND booking_date=CURDATE()",
      [admin],
    ),
    pool.query(
      "SELECT COALESCE(SUM(amount),0) total FROM bookings WHERE admin_id=? AND payment_status='paid' AND booking_status<>'cancelled'",
      [admin],
    ),
    pool.query(
      "SELECT COUNT(*) count FROM bookings WHERE admin_id=? AND booking_status='upcoming'",
      [admin],
    ),
  ]);
  return ok(res, {
    grounds: grounds[0].count,
    todayBookings: today[0].count,
    totalRevenue: Number(revenue[0].total),
    upcomingBookings: upcoming[0].count,
  });
});
const revenue = asyncHandler(async (req, res) => {
  const filter = req.query.filter || "monthly";
  let condition = "booking_date >= DATE_FORMAT(CURDATE(),'%Y-%m-01')";
  if (filter === "daily") condition = "booking_date=CURDATE()";
  if (filter === "weekly")
    condition = "booking_date>=DATE_SUB(CURDATE(), INTERVAL 7 DAY)";
  const [rows] = await pool.query(
    `SELECT * FROM bookings WHERE admin_id=? AND ${condition} ORDER BY booking_date`,
    [req.user.id],
  );
  return ok(res, rows);
});
module.exports = { stats, revenue };
