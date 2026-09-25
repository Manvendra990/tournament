# User panel username/phone + password authentication

Added without changing the existing admin authentication routes.

## New user APIs

- `POST /api/v1/auth/user/register`
  - body: `{ "username": "player1", "phone": "9876543210", "password": "secret123" }`
- `POST /api/v1/auth/user/login`
  - body: `{ "identifier": "player1", "password": "secret123" }`
  - `identifier` can be username or phone number.

## Existing admin APIs preserved

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`

Google/OTP endpoints are still present in the backend for compatibility, but the updated user-panel login UI now uses username/phone + password.

## Existing databases

Run `node sql/migrate.js` once. It safely adds nullable `users.username` plus the unique username index if they are missing. Existing admin/user rows remain intact.
