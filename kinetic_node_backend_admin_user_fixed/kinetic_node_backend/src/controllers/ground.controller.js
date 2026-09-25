const path = require("path");
const { pool } = require("../config/db");
const env = require("../config/env");
const { ApiError, asyncHandler, ok } = require("../utils/http");
const S = require("../utils/serializers");

async function imagesFor(ids) {
  if (!ids.length) return new Map();
  const [rows] = await pool.query(
    `SELECT ground_id,image_url FROM ground_images WHERE ground_id IN (${ids.map(() => "?").join(",")}) ORDER BY sort_order,id`,
    ids,
  );
  const map = new Map();
  for (const r of rows) {
    const k = String(r.ground_id);
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(r.image_url);
  }
  return map;
}
async function getOwnedGround(id, user) {
  const [rows] = await pool.query(
    "SELECT * FROM grounds WHERE id = ? LIMIT 1",
    [id],
  );
  const g = rows[0];
  if (!g) throw new ApiError(404, "Ground not found");
  if (user.role !== "superadmin" && Number(g.admin_id) !== Number(user.id))
    throw new ApiError(403, "Not allowed to access this ground");
  return g;
}
const listMine = asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    "SELECT * FROM grounds WHERE admin_id=? ORDER BY created_at DESC",
    [req.user.id],
  );
  const im = await imagesFor(rows.map((r) => r.id));
  return ok(
    res,
    rows.map((r) => S.ground(r, im.get(String(r.id)) || [])),
  );
});
const listPublic = asyncHandler(async (req, res) => {
  const { city, sportType } = req.query;
  let sql = "SELECT * FROM grounds WHERE status IN ('active','approved')",
    vals = [];
  if (city) {
    sql += " AND city=?";
    vals.push(city);
  }
  if (sportType) {
    sql += " AND sport_type=?";
    vals.push(sportType);
  }
  sql += " ORDER BY created_at DESC";
  const [rows] = await pool.query(sql, vals);
  const im = await imagesFor(rows.map((r) => r.id));
  return ok(
    res,
    rows.map((r) => S.ground(r, im.get(String(r.id)) || [])),
  );
});
const getOne = asyncHandler(async (req, res) => {
  const [rows] = await pool.query("SELECT * FROM grounds WHERE id=?", [
    req.params.id,
  ]);
  if (!rows[0]) throw new ApiError(404, "Ground not found");
  const im = await imagesFor([rows[0].id]);
  return ok(res, S.ground(rows[0], im.get(String(rows[0].id)) || []));
});
const create = asyncHandler(async (req, res) => {
  const b = req.body;
  const p =
    typeof b.pricing === "string" ? JSON.parse(b.pricing) : b.pricing || {};
  const amenities =
    typeof b.amenities === "string"
      ? JSON.parse(b.amenities)
      : b.amenities || [];
  if (!b.name || !b.sportType || !b.city || !b.location)
    throw new ApiError(422, "name, sportType, city and location are required");
  const [r] = await pool.query(
    `INSERT INTO grounds (admin_id,name,sport_type,city,location,latitude,longitude,amenities,rules,status,price_morning,price_afternoon,price_evening,price_weekend) VALUES (?,?,?,?,?,?,?,?,?,'active',?,?,?,?)`,
    [
      req.user.id,
      b.name,
      b.sportType,
      b.city,
      b.location,
      Number(b.latitude || 0),
      Number(b.longitude || 0),
      JSON.stringify(amenities),
      b.rules || "",
      Number(p.morning || 0),
      Number(p.afternoon || 0),
      Number(p.evening || 0),
      Number(p.weekend || 0),
    ],
  );
  if (req.files?.length) {
    for (let i = 0; i < req.files.length; i++)
      await pool.query(
        "INSERT INTO ground_images (ground_id,image_url,sort_order) VALUES (?,?,?)",
        [
          r.insertId,
          `${env.apiBaseUrl}/uploads/grounds/${path.basename(req.files[i].path)}`,
          i,
        ],
      );
  }
  req.app
    .get("io")
    ?.to(`admin:${req.user.id}`)
    .emit("ground:created", { groundId: String(r.insertId) });
  req.params.id = r.insertId;
  const [rows] = await pool.query("SELECT * FROM grounds WHERE id=?", [
    r.insertId,
  ]);
  const im = await imagesFor([r.insertId]);
  return ok(
    res,
    S.ground(rows[0], im.get(String(r.insertId)) || []),
    "Ground created",
    201,
  );
});
const update = asyncHandler(async (req, res) => {
  const g = await getOwnedGround(req.params.id, req.user);
  const b = req.body;
  const fields = {
    name: "name",
    sportType: "sport_type",
    city: "city",
    location: "location",
    latitude: "latitude",
    longitude: "longitude",
    rules: "rules",
    status: "status",
  };
  const sets = [],
    vals = [];
  for (const [k, c] of Object.entries(fields))
    if (b[k] !== undefined) {
      sets.push(`${c}=?`);
      vals.push(b[k]);
    }
  if (b.amenities !== undefined) {
    sets.push("amenities=?");
    vals.push(JSON.stringify(b.amenities));
  }
  if (b.pricing) {
    for (const [k, c] of Object.entries({
      morning: "price_morning",
      afternoon: "price_afternoon",
      evening: "price_evening",
      weekend: "price_weekend",
    }))
      if (b.pricing[k] !== undefined) {
        sets.push(`${c}=?`);
        vals.push(b.pricing[k]);
      }
  }
  if (!sets.length) throw new ApiError(422, "Nothing to update");
  vals.push(g.id);
  await pool.query(`UPDATE grounds SET ${sets.join(",")} WHERE id=?`, vals);
  req.app
    .get("io")
    ?.to(`admin:${g.admin_id}`)
    .emit("ground:updated", { groundId: String(g.id) });
  return ok(res, null, "Ground updated");
});
const toggleStatus = asyncHandler(async (req, res) => {
  const g = await getOwnedGround(req.params.id, req.user);
  const status = req.body.isActive === true ? "active" : "inactive";
  await pool.query("UPDATE grounds SET status=? WHERE id=?", [status, g.id]);
  req.app
    .get("io")
    ?.to(`admin:${g.admin_id}`)
    .emit("ground:updated", { groundId: String(g.id), status });
  return ok(res, { status }, "Ground status updated");
});
const uploadImages = asyncHandler(async (req, res) => {
  const g = await getOwnedGround(req.params.id, req.user);
  if (!req.files?.length) throw new ApiError(422, "Select at least one image");
  const urls = [];
  for (const f of req.files) {
    const url = `${env.apiBaseUrl}/uploads/grounds/${path.basename(f.path)}`;
    await pool.query(
      "INSERT INTO ground_images (ground_id,image_url) VALUES (?,?)",
      [g.id, url],
    );
    urls.push(url);
  }
  return ok(res, { urls }, "Images uploaded", 201);
});
const deleteImage = asyncHandler(async (req, res) => {
  const g = await getOwnedGround(req.params.id, req.user);
  const [r] = await pool.query(
    "DELETE FROM ground_images WHERE ground_id=? AND id=?",
    [g.id, req.params.imageId],
  );
  if (!r.affectedRows) throw new ApiError(404, "Image not found");
  return ok(res, null, "Image deleted");
});
module.exports = {
  listMine,
  listPublic,
  getOne,
  create,
  update,
  toggleStatus,
  uploadImages,
  deleteImage,
};
