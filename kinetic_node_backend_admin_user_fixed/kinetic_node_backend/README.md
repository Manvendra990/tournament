# Kinetic Slot Booking — Node.js + MySQL API

Generated from the uploaded Flutter admin app that currently uses Firebase Auth, Firestore and Firebase Storage.

## Firebase → API mapping

- Firebase Auth → JWT + bcrypt + `users` table
- `admin` / `users` Firestore collections → unified `users` table (`role`, `status`)
- `grounds` → `grounds` + `ground_images`
- `slots` → `slots`
- `bookings` → `bookings`
- Firebase Storage → local `/uploads` (replaceable with S3/Cloudinary)
- Firestore snapshot streams → REST refresh + Socket.IO events
- FCM can remain Firebase FCM; it is independent of the MySQL migration

## Setup

1. Install MySQL 8+ and Node.js 20+.
2. Create the database/tables:

```bash
mysql -u root -p < sql/schema.sql
```

3. Copy environment file:

```bash
cp .env.example .env
```

4. Set `DB_*`, `JWT_SECRET` and `API_BASE_URL` in `.env`.
5. Install and start:

```bash
npm install
npm run dev
```

Health: `GET http://localhost:3000/health`

## Main endpoints

### Auth
- `POST /api/v1/auth/register`
  - `{ "name":"Admin", "email":"admin@example.com", "phone":"9999999999", "password":"secret123", "role":"admin" }`
- `POST /api/v1/auth/login`
  - `{ "email":"admin@example.com", "password":"secret123" }`
- `GET /api/v1/auth/me` (Bearer token)

### Profile
- `GET /api/v1/profile`
- `PATCH /api/v1/profile` multipart: `name`, `phone`, `bio`, optional `photo`
- `PATCH /api/v1/profile/password`

### Grounds
- `GET /api/v1/grounds` admin's grounds
- `GET /api/v1/grounds/public`
- `GET /api/v1/grounds/:id`
- `POST /api/v1/grounds` multipart; images field name = `images`
- `PATCH /api/v1/grounds/:id`
- `PATCH /api/v1/grounds/:id/status` `{ "isActive": true }`
- `POST /api/v1/grounds/:id/images`
- `DELETE /api/v1/grounds/:id/images/:imageId`

### Slots
- `GET /api/v1/slots?groundId=1&date=2026-09-12`
- `POST /api/v1/slots`
- `POST /api/v1/slots/bulk`
- `PATCH /api/v1/slots/:id` (`status` and/or `price`)
- `DELETE /api/v1/slots/:id`

### Bookings
- `GET /api/v1/bookings/admin?from=2026-09-01&to=2026-09-30&status=upcoming`
- `GET /api/v1/bookings/mine`
- `POST /api/v1/bookings` user role, `{ "slotId":"1" }`
- `PATCH /api/v1/bookings/:id/cancel`

### Dashboard
- `GET /api/v1/dashboard/stats`
- `GET /api/v1/dashboard/revenue?filter=daily|weekly|monthly`

### Superadmin
- `GET /api/v1/admin/users`
- `PATCH /api/v1/admin/users/:id/status`

## Flutter changes required

The uploaded app still directly imports `firebase_auth`, `cloud_firestore`, and `firebase_storage`. Replace those calls with an API client. Store the returned JWT in secure storage/shared preferences and send:

`Authorization: Bearer <token>`

For Android emulator use `http://10.0.2.2:3000`; for a real phone use your PC LAN IP such as `http://192.168.x.x:3000` while both are on the same network.

### Response shape

```json
{ "success": true, "message": "OK", "data": {} }
```

The serializers intentionally use Flutter-friendly names such as `adminId`, `groundId`, `startTime`, `paymentStatus`, etc., so your current Dart models can be adapted with minimal changes.

## Important migration note

Your ZIP contains several empty/incomplete files (`auth_remote_datasource.dart`, `user_remote_datasource.dart`, `payment_remote_datasource.dart`, `storage_datasource.dart`, and some models/notifiers). The API therefore includes the concrete flows visible in the working source plus sensible payment/refund tables for the rules already present in `role_guard.dart`.

Before production deployment add HTTPS, cloud object storage, database backups, email/SMS password reset, payment-provider webhook signature verification, and production-grade logging/monitoring.
