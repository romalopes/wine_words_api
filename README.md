# Wine Prediction Rails app

This Rails application serves both a server-rendered wine library and the JSON API consumed by the React application.

## Run locally

Ensure `DATABASE_URL` is configured in `.env`, then run:

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Open `http://localhost:3000` to use the Rails interface:

- `/` — wine library
- `/wines/:slug` — individual wine and vintage notes

The JSON API is still available at `/api/v1`, including `/api/v1/wines`.

Create interface for Articles.
An article will have a textarea. Also, it will have many reviews.
