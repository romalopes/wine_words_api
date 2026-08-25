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

---

- add links to Add/Update/Delete for the items like in the react app.
- Change the "Wine Prediction" to "Wine Words".
- Allow CRUD to vintages from wines page.

---

Remove the NeoAuth authentication and add a devise authentication. First create the backend and frontend authentication for the rails app. Then, change the React app use this authentication with devise.

---

Create a dashboard/home page with a menu to Producers, Wines, Reviews and a login/sign up link. This menu should persist through the whole system. Also, create a login/sign up page in the rails app similar to the one in the react app.

---

Add a logo to the react and rails project. Also, change the tab icon to reflect this logo.

## The image to be used as logo is at: ./wine_project/wine_words.jpg

---

Add images to producer, wine and reviews. Each element can have more than one image.

---

Allow update the images in a interactive way.

---

In the react app, allow to view all the reviews. If the review is still draft, make it visible only to the author. Also, create an interface to create reviews from a button "Add Review".

In Rails app, change the dimentions of the images for the index reviews to the same as wines index.

---

In the rails app, do similar to the rails app. Add buttons to publish/unpublish of the review.

---

In file /wine_predicition_api/app/views/show.html.erb, can you change it to "remote" version, not needing to update the whole page?

`<% if @review.status == "draft" %>
        <%= button_to "Publish", review_path(@review.id), method: :patch, params: { review: { status: "published", published_at: Time.current } }, class: "btn btn--secondary" %>
      <% else %>
        <%= button_to "Unpublish", review_path(@review.id), method: :patch, params: { review: { status: "draft" } }, class: "btn btn--secondary" %>
      <% end %>`

---

PUt the styles that are in application.html.erb in a separated file.

---

Create Articles. The whole CRUD for Articles and add them to the dashboard.

Attributes(An article will have):

- Multiple images to be positioned on the of the article
- A title
- An abstract
- a rich textarea
- The article can be draft or published. Draft article will be seen only by the author.

Relationshipe:
An Article is written by a User, the author.
An article can be separated by categories. Create a table for categories
An Article can have many tags to be searched in the future. Create a table for Tags
An Article have many reviews. In the relationship betwen article and review, there will be a boolean about draft or published. If if the review(in the review table) is published, this other flag should also be selected as published to be shown.
An Article have zero to many wines.
An Article have zero to many producers.

This part can be based on this website: https://kasiasobiesiak.substack.com/ and it can be integrated with the home page. In other words, show the articles and reviews in the home page.

In the bottom of the article, the page can show the list of reviews(which the relationship has the tag published), wines and producers.

---

Create roles for users and a interface for this A user

---

Create a subscription concept. A user can have different kind of subscriptions
A user with the
