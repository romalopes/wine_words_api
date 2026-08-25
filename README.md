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

In rect app and rails app, Show in the list of reviews and articles the one image like with wines.

---

Allow to add and remove images from wines, review and articles interactively.

---

Change the relationship from "article has many wines" to "article has many vintages". The relationship between article and wine will be through vintanges. In the bottom of the article, show the list of vintage/wines selected.

In the new/edit article. Allow the user to search wines and then and vintages before selection.

After select the vintages, allow the user to select the reviews in each vintages.

Better keep the the article linked to review and to vintages separated..

- Article can have many vintages.
- Article can have many Reviews.

Reviews will keep having the relationship with Vintages. Vintages have many reviews.

After select the vintages, allow the user to select the reviews in each vintages. The user doesn't need to select any review if he doesn't want.

Add the interface in the "New Article" to link with the reviews as well. It looks like it is not present currently

---

Create roles for users and a interface for this. A user

Create roles for users and a interface for this task. A user can have many roles. In the future, the role will define the access to some pages and right to update or delete info.

Create the following roles:

- Super User
- Reviewer
- Reader
- Simple User

Link the first user to "Super User" role.

## When a new user is created or in the first login link the user to "Simple User" role.

Create a subscription concept to the system. Don't link with any payment yet, but keep it open for the future. A user can have one kind of subscription.
A user with the "super user" role will be able to add new substription

Attributes of subscriptions:

- Name
- Flag to show which is the most popular
- flag to define if it will be visible in the webpage.
- description
- monthly price
- anually price
- List of "Subscription Feature"

<!-- Relationship to a new table called "Subscription Feature".  Subscription can have many "Subscription Feature".
 Each -->

Create the following subscriptions types:

- FREE
- Consumer ($AUD 70/year)
- Trade ($AUD 240/year)
- Distributer ($AUD 400/year)
- Retail ($AUD 600/year)

When the user is created the use will be assigned to the FREE subscription.

Make a interface based on the websites:

- https://www.winefront.com.au/subscribe/
- https://www.jancisrobinson.com/membership

---

In Reviews, change the search for vintage in both react and rails apps.

First put a wine search input. When user write the name of wine, go to database and return all wines from that search. Then, when the user selects the wine, the vintages shows up.

If the the wine if now found, open a add wine with all the parameters of the wine with the vintage and create the wine to be reviewed. Then, continue with the review creation.

Make it all in Single page app.
