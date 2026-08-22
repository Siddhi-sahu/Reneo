authentication:

HTTP Request (e.g. GET /api/auth/me)
   │
   ▼
[1] server.ts-> app.ts (Express Server receives request)
   │
   ▼
[2] auth.routes.ts (Routes request to validator & controller)
   │
   ▼
[3] auth.validators.ts + validate.ts (Checks if input data is valid)
   │
   ▼
[4] middleware/auth.ts (`protect` middleware verifies Supabase Bearer token)
   │
   ▼
[5] controllers/auth.controller.ts (Executes business logic with Supabase client)
   │
   ▼
[6] middleware/errorHandler.ts (Formats response or handles error gracefully)