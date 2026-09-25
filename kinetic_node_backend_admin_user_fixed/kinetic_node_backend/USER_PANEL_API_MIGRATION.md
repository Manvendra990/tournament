# User Panel Node API Migration

The existing admin API routes are preserved. User-panel support was added alongside them.

## Added user endpoints
- `POST /api/v1/auth/google`
- `POST /api/v1/auth/otp/request`
- `POST /api/v1/auth/otp/verify`
- `GET /api/v1/payments/mine`

Existing user-compatible endpoints are reused:
- `GET /api/v1/grounds/public`
- `GET /api/v1/grounds/:id`
- `GET /api/v1/slots?groundId=...&date=YYYY-MM-DD`
- `POST /api/v1/bookings`
- `GET /api/v1/bookings/mine`
- `PATCH /api/v1/bookings/:id/cancel`
- `GET/PATCH /api/v1/profile`

## Database
Run the schema migration once after replacing the backend:

```bash
node sql/migrate.js
```

The migration is idempotent (`CREATE TABLE IF NOT EXISTS`) and adds `user_otps` for the non-Firebase OTP flow.

## Google sign-in
Set `GOOGLE_CLIENT_ID` in `.env` to your OAuth client ID. When it is configured, the backend validates the token audience in addition to validating the Google ID token.

## Phone OTP
Firebase phone auth is removed. The backend now owns the OTP flow. The included backend generates and stores hashed OTPs. In development it returns `devOtp` for testing. Before production, connect `sendOtpToProvider()` in `src/controllers/auth.controller.js` to your SMS provider.

## Flutter networking
The supplied user `lib` uses:

`http://localhost:3000/api/v1`

For Android emulator testing keep using:

```bash
adb reverse tcp:3000 tcp:3000
```

For a physical phone replace `localhost` in `lib/core/api/api_client.dart` with the backend machine/server address.
