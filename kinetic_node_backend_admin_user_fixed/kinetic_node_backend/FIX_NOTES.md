# Combined Admin + User Backend Fix Notes

## What was preserved
- Existing admin email/password registration and login routes.
- Existing admin ground, slot, dashboard and booking flows.
- Existing database data is not deleted or reset.

## Main runtime fix
The combined user authentication uses `users.username` and the `user_otps` table. An existing database created by the earlier admin-only backend may not contain them.

The server now runs an additive compatibility check on startup:
- adds nullable `users.username` if missing;
- adds unique index `uq_users_username` if missing;
- creates `user_otps` if missing.

This prevents user auth from failing simply because the old database was not manually migrated.

## Endpoints
Admin login:
`POST /api/v1/auth/login`
Body: `{ "email": "...", "password": "..." }`

User login:
`POST /api/v1/auth/user/login`
Body: `{ "identifier": "username-or-phone", "password": "..." }`

User registration:
`POST /api/v1/auth/user/register`
Body: `{ "username": "...", "phone": "...", "password": "..." }`

Health:
`GET /health`

## Important client-side diagnostic
Express already uses Morgan request logging. If pressing Login in Flutter produces absolutely no HTTP log in the Node terminal, the request is not reaching this backend. Check the Flutter API base URL/network setup.

Android emulator with a backend on the host machine can use either:
- `adb reverse tcp:3000 tcp:3000` with `http://localhost:3000/api/v1`, or
- the emulator host address such as `http://10.0.2.2:3000/api/v1`.

A physical phone must use the computer's LAN IP or deployed server URL, not phone-local `localhost`.
