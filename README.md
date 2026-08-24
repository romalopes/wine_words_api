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

---

Create Articles. The whole CRUD for Articles and add them to the dashboard.

Attributes(An article will have):

- Multiple images to be positioned on to of the article
- A title
- An abstract
- a rich textarea
- The article can be draft or published. Draft article will be seen only by the author.

Relationshipe:
An Article is written by a User, the author.
An article can be separated by categories. Create a table for categories
An Article can have many tags to be searched in the future. Create a table for Tags
An Article have many reviews.
An Article have zero to many wines.
An Article have zero to many producers.

This part can be based on this website: https://kasiasobiesiak.substack.com/ and it can be integrated with the home page. In other words, show the articles and reviews in the home page.

In the bottom of the article, the page can show the list of reviews, wines and producers.

---

- add links to Add/Update/Delete for the items like in the react app.
- Change the "Wine Prediction" to "Wine Words".
- Allow CRUD to vintages from wines page.

---

Remove the NeoAuth authentication and add a devise authentication. First create the backend and frontend authentication for the rails app. Then, change the React app use this authentication with devise.

---

Create a dashboard/home page with a menu to Producers, Wines, Reviews and a login/sign up link. This menu should persist through the whole system. Also, create a login/sign up page in the rails app similar to the one in the react app.
