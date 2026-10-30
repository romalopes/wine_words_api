# Playwright API environment

The browser suite uses `RAILS_ENV=e2e` and the PostgreSQL database
`wine_words_api_e2e` by default. It never reuses the Rails `test`,
`development`, or production database.

```bash
RAILS_ENV=e2e bin/rails e2e:prepare
RAILS_ENV=e2e TEST_ACCESS_PASSWORD=playwright-access \
  FRONTEND_URL=http://127.0.0.1:4173 bin/rails server -p 3100 -b 127.0.0.1
```

`e2e:prepare` is destructive and includes guards for both the Rails environment
and exact database name. Override the database only with `E2E_DATABASE_NAME`
and `E2E_DATABASE_URL`. The seed creates deterministic Admin, Reviewer, Reader,
and Guest accounts; all use `E2E_USER_PASSWORD` (default `Playwright123!`). Mail,
Active Job, storage, and cache use test-safe adapters.
