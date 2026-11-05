# frozen_string_literal: true

# db/seeds/articles_and_reviews.rb
#
# Standalone seed (run via `bin/rails runner db/seeds/articles_and_reviews.rb`).
#
# NOT idempotent: every run creates NEW rows.
#
# Creates on every run:
#   * 5 new published Article rows  (random producers/wines referenced via links).
#   * 20 new published Review rows  (on 20 RANDOM existing vintages).
#   * article <-> review links  (article #1 links to ALL 20 reviews; the other
#     four articles link to rotating, overlapping subsets of ~5 reviews each;
#     reviews are SHARED across articles).
#   * 2 additional (existing) Producers linked to each Article.
#   * 1-2 additional Vintages WITHOUT any review linked to each Article.
#
# Titles/slugs get a per-run stamp suffix so repeated runs never collide.
# Reuses existing seeded producers / wines / vintages / users and does NOT
# create any new producers, wines or vintages.

ActiveRecord::Base.transaction do
  puts "Seeding articles and reviews..."

  run_tag = Time.current.strftime("%Y%m%d%H%M%S")

  # ---------------------------------------------------------------------------
  # Author. Reuse an existing seeder user; fall back to a freshly created one so
  # the seed stays self-contained even in a blank database.
  # ---------------------------------------------------------------------------
  author =
    User.find_by(email: "test@example.com") ||
    User.first ||
    User.create!(email: "seeder@example.com", password: "password", first_name: "Seeder")

  now = Time.current

  # ---------------------------------------------------------------------------
  # 1) Five new published articles on every run (titles stamped with run_tag).
  # ---------------------------------------------------------------------------
  article_titles = [
    "Regional Spotlight: Barossa Valley",
    "Vintage Focus: Central Otago Pinot",
    "Cellar Insights: aged Riesling",
    "Producer Deep-Dive: Alkina",
    "Harvest Review: 2022 Shiraz"
  ]
  article_bodies = [
    "Barossa Valley continues to deliver world-class Shiraz with concentration and spice.",
    "Central Otago's cool-climate site selection produces Pinot Noir of rare precision.",
    "Riesling with a little bottle age reveals layers of honey, toast and mineral.",
    "Alkina Wine Estate brings traditional winemaking together with site-driven detail.",
    "The 2022 Shiraz harvest gave dense fruit, fine tannin and a long, spiced finish."
  ]

  articles = article_titles.map.with_index do |title, i|
    Article.create!(
      title:         "#{title} (seed #{run_tag})",
      abstract:      "Seeded article ##{i + 1}.",
      body:          article_bodies[i],
      status:        "published",
      published_at:  now,
      user:          author
    )
  end

  # ---------------------------------------------------------------------------
  # Pick 20 RANDOM vintages (random producers / random wines). If fewer than
  # 20 vintages exist, create random vintages for existing wines so the seed
  # can proceed regardless of database size.
  # ---------------------------------------------------------------------------
  random_vintages = Vintage.includes(wine: :producer).order("RANDOM()").limit(20).to_a

  if random_vintages.size < 20
    needed = 20 - random_vintages.size
    puts "Only #{random_vintages.size} vintages found; creating #{needed} random vintages..."

    wines = Wine.order("RANDOM()").to_a
    if wines.empty?
      raise "Cannot seed reviews: no wines exist in the database to create vintages for."
    end

    current_year = Time.current.year
    existing_keys = random_vintages.map { |v| [v.wine_id, v.year] }.to_set

    created = 0
    attempts = 0
    max_attempts = needed * 100

    while created < needed && attempts < max_attempts
      wine = wines.sample
      year = rand(1900..current_year)
      next if existing_keys.include?([wine.id, year])

      begin
        Vintage.create!(wine: wine, year: year)
        existing_keys.add([wine.id, year])
        created += 1
      rescue ActiveRecord::RecordInvalid
        # retry with a different wine / year combo
      end
      attempts += 1
    end

    raise "Could only create #{created} of #{needed} needed random vintages." if created < needed

    # Re-fetch vintages so `chosen` below includes the newly created ones.
    random_vintages = Vintage.includes(wine: :producer).order("RANDOM()").limit(20).to_a
  end

  chosen = random_vintages.map do |vt|
    { producer: vt.wine.producer, wine: vt.wine, vintage: vt }
  end

  # ---------------------------------------------------------------------------
  # 2) Twenty NEW reviews on the randomly chosen vintages (titles stamped
  #    with run_tag, random score 60..100).
  # ---------------------------------------------------------------------------
  reviews = chosen.map do |c|
    wine    = c[:wine]
    vintage = c[:vintage]
    title   = "#{wine.name} #{vintage.year} Review (seed #{run_tag})"
    score   = rand(60..100)

    Review.create!(
      vintage:       vintage,
      title:         title,
      comment:       "Seeded review for #{wine.name} #{vintage.year}.",
      score:         score,
      status:        "published",
      user:          author,
      published_at:  now,
      drink_from:    vintage.year,            # drink_from >= vintage.year -> validation passes
      drink_to:      vintage.year + 5
    )
  end

  # ---------------------------------------------------------------------------
  # 3) article <-> review links (ArticleReview.status = "published").
  #    Article #1 links to ALL 20 reviews; articles 2-5 link to rotating
  #    overlapping subsets of ~5 reviews each. Reviews are shared.
  # ---------------------------------------------------------------------------
  link_review_to_article = lambda do |article, review|
    ArticleReview.find_or_create_by!(article: article, review: review) do |ar|
      ar.status = "published"
    end
  end

  article_review_assignments = {
    articles[0] => (0...20).to_a,        # all 20 reviews
    articles[1] => [0, 1, 2, 3, 4],
    articles[2] => [4, 5, 6, 7, 8],
    articles[3] => [9, 10, 11, 12, 13],
    articles[4] => [15, 16, 17, 18, 19]
  }

  article_review_assignments.each do |article, indices|
    indices.each { |i| link_review_to_article.call(article, reviews[i]) }
  end

  # ---------------------------------------------------------------------------
  # 4) Two additional (existing) producers linked to each article
  #    (ArticleProducer has only article_id + producer_id; no role column).
  #    Deterministic picks -> idempotent re-runs.
  # ---------------------------------------------------------------------------
  review_producer_ids = chosen.map { |c| c[:producer].id }.uniq
  other_producers = Producer.where.not(id: review_producer_ids).order(:id).to_a
  half = [other_producers.size / 2, 1].max

  articles.each_with_index do |article, idx|
    pick1 = other_producers[idx % other_producers.size]
    pick2 = other_producers[(idx + half) % other_producers.size]
    [pick1, pick2].uniq.each do |producer|
      ArticleProducer.find_or_create_by!(article: article, producer: producer)
    end
  end

  # ---------------------------------------------------------------------------
  # 5) One or two extra Vintages WITHOUT any review linked to each article
  #    (ArticleVintage has only article_id + vintage_id). Deterministic picks
  #    -> idempotent re-runs.
  # ---------------------------------------------------------------------------
  review_vintage_ids = chosen.map { |c| c[:vintage].id }.uniq
  no_review_vintages = Vintage
                       .where.not(id: review_vintage_ids)
                       .left_joins(:reviews)
                       .where(reviews: { id: nil })
                       .order(:id)
                       .to_a

  articles.each_with_index do |article, idx|
    next if no_review_vintages.empty?

    count  = idx.zero? ? 2 : 1
    picks  = count.times.map { |j| no_review_vintages[(idx + j) % no_review_vintages.size] }
    picks.uniq.each do |vintage|
      ArticleVintage.find_or_create_by!(article: article, vintage: vintage)
    end
  end

  # ---------------------------------------------------------------------------
  # 6) Reset PK sequences to match the existing seed-file style.
  # ---------------------------------------------------------------------------
  ActiveRecord::Base.connection.reset_pk_sequence!("reviews")
  ActiveRecord::Base.connection.reset_pk_sequence!("articles")

  puts "Seeding articles and reviews complete."
  puts "  - #{Article.count} articles"
  puts "  - #{Review.count} reviews"
  puts "  - #{ArticleReview.count} article <-> review links"
  puts "  - #{ArticleProducer.count} article <-> producer links"
  puts "  - #{ArticleVintage.count} article <-> vintage links"
end