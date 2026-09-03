# frozen_string_literal: true

# db/seeds/articles_and_reviews.rb
#
# Standalone seed (run via `bin/rails runner db/seeds/articles_and_reviews.rb`).
#
# Creates:
#   * 5 published Article rows  (idempotent by title).
#   * 20 published Review rows  (on existing seeded vintages).
#   * article <-> review links  (article #1 links to ALL 20 reviews; the other
#     four articles link to rotating, overlapping subsets of ~5 reviews each;
#     reviews are SHARED across articles).
#   * 2 additional (existing) Producers linked to each Article.
#   * 1-2 additional Vintages WITHOUT any review linked to each Article.
#
# Reuses existing seeded producers / wines / vintages / users and does NOT
# create any new producers, wines or vintages. Idempotent: re-running the file
# is a no-op for existing rows (guards use find_or_create_by!).

ActiveRecord::Base.transaction do
  puts "Seeding articles and reviews..."

  # ---------------------------------------------------------------------------
  # Author. Reuse an existing seeder user; fall back to a freshly created one so
  # the seed stays self-contained even in a blank database.
  # ---------------------------------------------------------------------------
  author =
    User.find_by(email: "test@example.com") ||
    User.first ||
    User.create!(email: "seeder@example.com", password: "password", name: "Seeder")

  now = Time.current

  # ---------------------------------------------------------------------------
  # 1) Five published articles (find_or_create! by title -> idempotent).
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
    Article.find_or_create_by!(title: title) do |a|
      a.abstract     = "Seeded article ##{i + 1}."
      a.body         = article_bodies[i]
      a.status       = "published"
      a.published_at = now
      a.user         = author
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers: reuse existing producers / wines / vintages.
  # ---------------------------------------------------------------------------
  producers = Producer.order(:id)

  # Pick 20 distinct vintages across existing producers (up to 2 per producer,
  # latest years first). Top up from the whole vintage table if needed.
  chosen = []
  seen_vintage_ids = {}

  producers.each do |producer|
    break if chosen.size >= 20

    Wine.where(producer_id: producer.id)
        .joins(:vintages)
        .distinct
        .order(:id)
        .limit(2)
        .each do |wine|
      next if chosen.size >= 20
      wine.vintages.order(year: :desc).limit(2).each do |vt|
        next if seen_vintage_ids[vt.id]
        next if chosen.size >= 20
        seen_vintage_ids[vt.id] = true
        chosen << { producer: producer, wine: wine, vintage: vt }
      end
    end
  end

  if chosen.size < 20
    Vintage.order(:id).each do |vt|
      break if chosen.size >= 20
      next if seen_vintage_ids[vt.id]
      seen_vintage_ids[vt.id] = true
      chosen << { producer: vt.wine.producer, wine: vt.wine, vintage: vt }
    end
  end

  if chosen.size < 20
    raise "Not enough distinct vintages in the database to create 20 reviews (found #{chosen.size})."
  end

  chosen = chosen.first(20)

  # ---------------------------------------------------------------------------
  # 2) Twenty reviews on the chosen vintages (find_or_create! by vintage+title).
  # ---------------------------------------------------------------------------
  reviews = chosen.map.with_index do |c, i|
    wine    = c[:wine]
    vintage = c[:vintage]
    title   = "#{wine.name} #{vintage.year} Review"
    score   = 60 + (i % 41) # deterministic 60..100

    Review.find_or_create_by!(vintage: vintage, title: title) do |r|
      r.comment      = "Seeded review for #{wine.name} #{vintage.year}."
      r.score        = score
      r.status       = "published"
      r.user         = author
      r.published_at = now
      r.drink_from   = vintage.year            # drink_from >= vintage.year -> validation passes
      r.drink_to     = vintage.year + 5
    end
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