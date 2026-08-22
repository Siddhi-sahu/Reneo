
## Implemented Now

- Supabase Auth registration, login, and current-user endpoints.
- `profiles` table linked to Supabase `auth.users`.
- `SELLER` and `CUSTOMER` roles stored in PostgreSQL.
- Core PostgreSQL schema migration for `profiles`, `stores`, `products`,
  `inventory`, `orders`, `order_items`, and `idempotency_keys`.
- RLS policies for the core tables.
- Schema constraints and indexes prepared for product APIs, search, orders,
  concurrency, and idempotency.

## Local Setup

1. Create the backend environment file:

```bash
cp backend/.env.example backend/.env
```

2. Fill in Supabase values:

```bash
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
```

3. Run the SQL migration in Supabase:

```text
supabase/migrations/001_core_schema.sql
```

For now, paste it into the Supabase SQL editor or run it through the Supabase
CLI once the CLI is added to the project.

4. Install and build the backend:

```bash
cd backend
npm install
npm run build
```

5. Start the API:

```bash
cd backend
npm run dev
```

The API runs at `http://localhost:8000/api` when `PORT=8000`.

## Verification

```bash
cd backend && npm run build
```

Known limitations at this checkpoint:

- Product API routes are not implemented yet.
- Order creation is not implemented yet.
- The concurrency test is not implemented yet.