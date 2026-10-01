function safeJson(value, fallback = []) {
  if (value == null) return fallback;
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}
function timeString(v) {
  return v ? String(v).slice(0, 5) : v;
}
function ground(row, images = []) {
  return {
    id: String(row.id),
    adminId: String(row.admin_id),
    name: row.name,
    sportType: row.sport_type,
    city: row.city,
    location: row.location,
    latitude: Number(row.latitude),
    longitude: Number(row.longitude),
    images,
    amenities: safeJson(row.amenities, []),
    rules: row.rules || "",
    status: row.status,
    pricing: {
      morning: Number(row.price_morning),
      afternoon: Number(row.price_afternoon),
      evening: Number(row.price_evening),
      weekend: Number(row.price_weekend),
    },
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
function slot(row) {
  return {
    id: String(row.id),
    groundId: String(row.ground_id),
    sportType: row.sport_type || '',
    date: row.slot_date,
    startTime: timeString(row.start_time),
    endTime: timeString(row.end_time),
    price: Number(row.price),
    status: row.status,
    createdAt: row.created_at,
  };
}
function booking(row) {
  return {
    id: String(row.id),
    userId: String(row.user_id),
    adminId: String(row.admin_id),
    groundId: String(row.ground_id),
    groundName: row.ground_name,
    slotId: String(row.slot_id),
    date: row.booking_date,
    startTime: timeString(row.start_time),
    endTime: timeString(row.end_time),
    amount: Number(row.amount),
    paymentStatus: row.payment_status,
    bookingStatus: row.booking_status,
    razorpayPaymentId: row.payment_reference || "",
    createdAt: row.created_at,
  };
}
function user(row) {
  return {
    id: String(row.id),
    name: row.name,
    username: row.username || "",
    email: row.email,
    phone: row.phone,
    role: row.role,
    status: row.status,
    bio: row.bio || "",
    photoUrl: row.photo_url || "",
    createdAt: row.created_at,
  };
}
module.exports = { safeJson, ground, slot, booking, user };
