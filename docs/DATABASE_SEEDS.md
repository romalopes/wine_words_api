# Database seed scripts

This guide describes all 10 Ruby files in [`db/seeds/`](../db/seeds/), their
prerequisites, effects, and execution commands. It describes the current code;
seed scripts have not been executed as part of writing this guide.

## Before running a seed

Complete the [local setup](LOCAL_AND_DEPLOYMENT_SETUP.md) first: install the Ruby
bundle, configure `.env.development.local`, and create/migrate a dedicated
PostgreSQL development database. Run the commands here from the API repository
root (`wine_prediction_api/` in the shared workspace).

Check the actual connection without printing its password:

```bash
bin/rails runner -e development 'c = ActiveRecord::Base.connection_db_config; puts({ environment: Rails.env, database: c.database, host: c.configuration_hash[:host] || "local socket" }.inspect)'
```

`-e development` selects the Rails environment, but **does not guarantee that
`DATABASE_URL` points to development**. Check the reported database and host,
including any exported shell configuration. Use a disposable database for the
destructive scripts; see [backup and restore](DATABASE_BACKUP_AND_RESTORE.md)
if you need to preserve existing data.

Run one file with Rails runner, which loads the application and its models:

```bash
bin/rails runner -e development db/seeds/countries.rb
```

Do not use plain `ruby db/seeds/countries.rb`. There is no custom
`db:seed:grapes` task in `lib/tasks`, despite the comment in `grapes.rb`.
Use a fresh runner process for each file: some scripts mutate their in-memory
seed hashes and define global constants/helpers, so repeatedly loading them in
one console session is unreliable.

Most files do not wrap the whole operation in a transaction. A failure can leave
partial changes, and an error does not undo earlier deletions. There is no built-in
dry-run option. Model callbacks also run for normal saves and destroys.

## Suggested order for a new disposable database

Run each command separately and check its output before continuing:

```bash
bin/rails runner -e development db/seeds/countries.rb
bin/rails runner -e development db/seeds/regions.rb
bin/rails runner -e development db/seeds/grapes.rb
bin/rails runner -e development db/seeds/volume_ml.rb
bin/rails runner -e development db/seeds/subscriptions.rb
bin/rails runner -e development db/seeds/producers.rb
bin/rails runner -e development db/seeds/wines.rb
```

This is a dependency order, not a guarantee that every seed will succeed with all
current validations. In particular, grapes must be loaded before producer/wine
associations exist, and wines must be loaded before creating reviews you want to
keep. The content generators/importers below are optional; do not run all scripts
with a wildcard.

These files do not provide the full taste-profile/role dataset from `db/seeds.rb`.
An application can still need additional reference data or a sanitized restore for
features such as taste matching.

## Script reference

### `countries.rb` — country catalogue

[Source](../db/seeds/countries.rb)

Creates countries with names, two-letter codes, and wine-country metadata. Matches
existing rows by **both name and code**. Existing rows have `is_wine_country`
refreshed, but other attributes are assigned only when a row is created.

Requires the migrated `countries` table. Run before regions and producers. Reruns
do not intentionally delete or duplicate matching countries, but a changed name
with an existing code (or vice versa) can fail uniqueness validation. The grape
country-linking code at the bottom is commented out and does not execute.

```bash
bin/rails runner -e development db/seeds/countries.rb
```

### `regions.rb` — geographic hierarchy

[Source](../db/seeds/regions.rb)

Recursively creates country-specific regions and child regions, including state
and appellation flags. Matches by name, country, and parent; refreshes the flags
on existing matches. It does not delete existing regions.

Run `countries.rb` first. Although this script tries to create missing countries
by name, it supplies no country code, which the current `Country` model requires.
If a country name is missing or differs between catalogues, reconcile it before
retrying. Region name/slug validations can also reject conflicting existing data.

```bash
bin/rails runner -e development db/seeds/regions.rb
```

### `grapes.rb` — replace the grape catalogue

[Source](../db/seeds/grapes.rb)

**Deletes every grape with `Grape.delete_all`**, resets the PostgreSQL primary-key
sequence, then creates the listed varieties with colour, origin text, synonyms,
regions, tasting notes, serving suggestions, blending flags, and relevance.

Run only on a disposable database before linking grapes to producers or wines.
`delete_all` bypasses model destroy callbacks: existing join-table references may
block deletion through foreign keys or become invalid if constraints are absent.
This is a destructive rebuild, not a safe upsert on an established catalogue.
The origin is stored as text; this file does not resolve it to `country_id`.

```bash
bin/rails runner -e development db/seeds/grapes.rb
```

### `volume_ml.rb` — bottle sizes

[Source](../db/seeds/volume_ml.rb)

Creates 12 bottle-volume records, from stored value `187` (label `187.5 ml`) through
`12000` (12 L). Marks a newly created 750 ml row as the default.

No other seed is required. Matches by numeric value, so reruns add missing sizes
without duplicating existing ones. Existing labels and default flags are **not**
updated. Run before wines to populate the bottle-size catalogue.

```bash
bin/rails runner -e development db/seeds/volume_ml.rb
```

### `subscriptions.rb` — plans and features

[Source](../db/seeds/subscriptions.rb)

Creates a catalogue of 10 features and creates or updates five plans: `free`,
`consumer`, `trade`, `distributor`, and `retail`. Sets prices, descriptions,
visibility, active/default/popular flags, ordering, and rank.

No other seed is required. Features match by slug and retain existing names.
Plans match by slug, but **each run overwrites their configured attributes and
destroys/rebuilds their feature links**. It does not delete unrelated plans or
features, subscribe existing users, or provision Stripe products/prices. Run before
creating sample users if they should receive the default plan through callbacks.

```bash
bin/rails runner -e development db/seeds/subscriptions.rb
```

### `producers.rb` — producers, addresses, and associations

[Source](../db/seeds/producers.rb)

Creates or updates producers by name, maps address fields into the associated
`Address`, and adds links to matching grapes and regions. It extracts and prints
`logo_url` but does not download or attach logos.

Requires countries with the exact names used in the dataset; an absent country
causes the `country.id` lookup to fail. Seed grapes and regions first for complete
associations: missing matches are silently skipped. Reruns overwrite seeded
producer/address fields and add missing links without clearing all existing links
(model callbacks may still affect associations). There is no active bulk producer
deletion; its `delete_all` line is commented out.

```bash
bin/rails runner -e development db/seeds/producers.rb
```

### `wines.rb` — replace wines and build vintages

[Source](../db/seeds/wines.rb)

**Calls `Wine.destroy_all` before importing anything**, then resets sequences for
wines and their grape/region join tables. Wine destruction cascades through model
associations, including vintages and their reviews. Existing content can therefore
be removed even if the import subsequently fails or skips every entry.

Creates the listed wines, builds their vintage years, and associates grapes and
regions. Requires producers with matching names; entries without a matching
producer are silently skipped. Grape names/synonyms and region names use partial,
case-insensitive matching and select the first result, so inspect ambiguous matches.
Run after countries, regions, grapes, volumes, and producers. Every rerun rebuilds
the wine dataset; it is not a safe update of existing wines.

```bash
bin/rails runner -e development db/seeds/wines.rb
```

### `articles_and_reviews.rb` — synthetic published content

[Source](../db/seeds/articles_and_reviews.rb)

Creates five published articles and 20 published reviews on randomly selected
existing vintages. Scores are random from 60 to 100. The first article links all
20 reviews; the other four each link five overlapping selections. It also links
extra producers and unreviewed vintages to the articles. Titles receive a timestamp.

Prerequisites are stricter than the introductory comment suggests:

- At least 20 distinct vintages, each with a wine and producer.
- At least one producer outside those represented by the 20 selected vintages.
  Two or more are needed for two distinct additional producer links per article.
- At least one remaining vintage with no reviews. Two or more are needed for the
  first article to receive two distinct extra vintage links.

The script raises when fewer than 20 vintages exist; an empty extra-producer or
unreviewed-vintage pool causes a modulo-by-zero error. Selection is random, so
having multiple producers alone does not guarantee an unused producer remains.

Reuses the designated test user, otherwise the first user, otherwise creates
`seeder@example.com` with password `password`. That fallback is development data,
not an administrator account. Every successful rerun creates additional content
and may exhaust the unreviewed pool. The script wraps its database work in one
transaction, so an exception rolls back the rows created in that run.

```bash
bin/rails runner -e development db/seeds/articles_and_reviews.rb
```

### `substract_reviews_articles_seed.rb` — fixed-list Substack import

[Source](../db/seeds/substract_reviews_articles_seed.rb)

Imports the hard-coded `URLS` list rather than the RSS feed. Preserves hyperlinks
as Markdown in extracted text, creates articles/reviews and categories, and attempts
to attach lead images. Keep the filename's existing `substract` spelling in commands.

For review titles matching `Review: <Wine Name> <20xx>`, finds a wine by
case-insensitive name or creates one, then finds/creates its vintage. Tries to match
the wine name's last word to an existing grape. New wines default to white and use
the first producer; the fallback `Unknown Producer` creation can fail current
required email/type validations. Seed producers first and review attribution.
Unparseable titles fall back to `Vintage.first`, which can be absent or unrelated.

Parses score (fallback 90), drinking window, tasted date, alcohol, closure, and
price where supported by its text patterns. It can **overwrite existing wine
alcohol/closure and vintage prices**. New wines also receive the review's lead image.

Requires network access, configured storage, and appropriate catalogue data as
above. Uses the same author fallback strategy as the RSS importer. It also chooses
an unused slug before lookup, so reruns create duplicate content. The URL list
itself contains a duplicate entry. There is no whole-import transaction; wine,
vintage, category, or image changes can persist even if a later review save fails.

```bash
bin/rails runner -e development db/seeds/substract_reviews_articles_seed.rb
```

## How this differs from `bin/rails db:seed`

Rails' `db:seed` runs [`db/seeds.rb`](../db/seeds.rb). That file currently does
**not** load these 10 scripts, even though some individual file comments suggest
it does. Instead it deletes wines, profiles, taste parameters and links, vintages,
users, reviews, articles, and roles before rebuilding roles and taste-profile data.
It is a separate destructive operation, not a shortcut for the sequence above.

`db:prepare` can also invoke the main seed file when initializing a database. Use
`db:create db:migrate` for the local setup path described in the README. Do not run
the main seed after loading catalogue or editorial data that you want to retain.

## Verify results and handle failures

Inspect counts after each relevant step:

```bash
bin/rails runner -e development '[Country, Region, Grape, VolumeMl, Subscription, SubscriptionFeature, Producer, Wine, Vintage, Article, Review].each { |model| puts "#{model.name}: #{model.count}" }'
```

Also check associations and rendered content in the app; counts alone cannot reveal
skipped producer matches, wrong vintage attribution, missing images, or duplicates.
If a command fails, inspect its first exception and the script's rerun behaviour
before retrying. Do not blindly rerun destructive scripts to repair a partial import.
Restore a disposable database from a known state when needed.

For Substack imports, inspect content and image warnings individually: external
page structure and availability can change, and some setup errors occur outside
the per-record rescue block. Both importers can stop after already saving data.
