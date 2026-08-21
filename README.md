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

Create Articles. The whole CRUD for Articles

An article will have a textarea with images on top. An article can be separated by categories. Also, an Article can have many tags to be searched in the future. Also, it will have many reviews.

This part can be based on this website: https://kasiasobiesiak.substack.com/

Remove the NeoAuth authentication and add a devise authentication. First create the backend and frontend authentication for the rails app. Then, change the React app use this authentication with devise.
