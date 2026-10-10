# db/seeds/front_wine_seed.rb
# --------------------------------------------------------------
# Seed script for Kasia's Wine Front reviews.
# --------------------------------------------------------------
require "csv"
require "open-uri"
require "uri"
require "date"

# ------------------------------------------------------------------
# Helper data
# ------------------------------------------------------------------
GRAPE_VARIETIES = %w[
  chardonnay pinot\ noir riesling sauvignon\ blanc semillon
  shiraz syrah cabernet\ sauvignon merlot malbec tempranillo
  grenache mourvedre viognier gewürztraminer pinot\ gris
  pinot\ blanc chenin\ blanc marsanne roussanne
  prosecco champagne sparkling
].freeze

# Map CSV closure values to the allowed list in Wine::CLOSURES
CLOSURE_MAP = {
  "screwcap"        => "Screw cap",
  "diam"            => "Diam",
  "cork"            => "Cork",
  "crownseal"       => "Crownseal",
  "synthetic"       => "Synthetic",
  "glass stopper"   => "Glass Stopper",
  "nomacorc plantcorc" => "Nomacorc PlantCorc",
  "vino-lok"        => "Vino-Lok",
  "agglomerate"     => "Agglomerate"
}.freeze

# WordPress thumbnail URLs look like `name-104x300.png` or `name-300x225.jpg`.
# Stripping the `-WxH` suffix yields the full-size original, which is what
# we want to store (the hero CSS uses `contain` so nothing is cropped).
def full_size_image_url(url)
  return url if url.blank?
  url.sub(/-\d+x\d+(?=\.(?:jpe?g|png|webp|gif)(?:[?#]|$))/i, "")
end

# Attach a remote image URL to a Wine via ActiveStorage (Image + file).
# Idempotent: skips when the URL is blank OR the wine already has an image.
# Returns true when an image was attached, false otherwise.
# NOTE: must run OUTSIDE the outer CSV transaction — network downloads
# inside a DB transaction hold the connection open and can time out.
def attach_wine_image!(wine, image_url_raw)
  return false if image_url_raw.blank?
  return false if wine.images.exists?

  url = full_size_image_url(image_url_raw.split.first)
  return false if url.blank?

  begin
    uri = URI.parse(url)
    filename = File.basename(uri.path.presence || "wine.jpg")
    filename = "wine.jpg" if filename.blank? || filename == "/"
    downloaded = URI.open(url, read_timeout: 20)
    content_type = downloaded.content_type
    unless Image::ALLOWED_CONTENT_TYPES.include?(content_type)
      puts "  ⚠️  Skipping image (unsupported type #{content_type}): #{url}"
      return false
    end
    image = wine.images.build(primary: wine.images.empty?)
    image.file.attach(io: downloaded, filename: filename, content_type: content_type)
    image.save!
    puts "  🖼️  Attached image to #{wine.name}: #{url}"
    true
  rescue StandardError => e
    puts "  ⚠️  Could not attach image #{url}: #{e.class} #{e.message}"
    false
  end
end

# ------------------------------------------------------------------
# Find / create the author user
# ------------------------------------------------------------------
author = User.find_or_create_by!(email: "kasia@mywineadviser.com.au") do |u|
  u.password = SecureRandom.hex(16)   # dummy – the user already exists in prod
  u.name     = "Kasia Sobiesiak"
end

# ------------------------------------------------------------------
# Path to the CSV that ships with the repo (adjust if needed)
# ------------------------------------------------------------------
csv_path = Rails.root.join("db", "data", "Kasia_Wine_Front_All_Reviews.csv")
$front_seed_created_reviews = 0
$front_seed_updated_reviews = 0
$front_seed_created_articles = 0
$front_seed_updated_articles = 0
$front_seed_attached_images = 0
$front_seed_pending_images = [] # [wine_id, image_url] — attached AFTER commit
ActiveRecord::Base.transaction do
  CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
    # ------------------------------------------------------------------
    # 1️⃣  Basic fields
    # ------------------------------------------------------------------
    wine_article      = row["Wine / Article"]&.strip
    next if wine_article.blank?

    publication_date  = row["Publication Date"]&.strip
    review_body       = row["Review Text"]&.strip
    score_raw         = row["Score"]&.strip                # e.g. "94 Points"
    tasted_raw        = row["Date Tasted"]&.strip          # e.g. "Sep26"
    alcohol_raw       = row["Alcohol"]&.strip              # e.g. "13%"
    price_raw         = row["Price"]&.strip                # e.g. "$50"
    closure_raw       = row["Closure"]&.strip
    drink_from_raw    = row["Drink From"]&.strip
    drink_by_raw      = row["Drink By"]&.strip
    categories_raw    = row["Categories"]&.strip
    image_url_raw     = row["Image URLs"]&.strip

    # ------------------------------------------------------------------
    # 2️⃣  Parse score (numeric part only)
    # ------------------------------------------------------------------
    score = score_raw[/\d+/]&.to_i

    # ------------------------------------------------------------------
    # 3️⃣  Parse vintage year (last 4‑digit number in the wine name)
    # ------------------------------------------------------------------
    vintage_year_match = wine_article.match(/(\d{4})\s*$/)
    vintage_year = vintage_year_match ? vintage_year_match[1].to_i : nil

    # ------------------------------------------------------------------
    # 4️⃣  Wine name + grape(s)  (remove trailing year)
    # ------------------------------------------------------------------
    wine_name_grape = wine_article.sub(/\s*\d{4}\s*$/, "").strip

    # ------------------------------------------------------------------
    # 5️⃣  Detect grapes from the name (simple word‑match against list)
    # ------------------------------------------------------------------
    detected_grapes = GRAPE_VARIETIES.select do |g|
      # word‑boundary, case‑insensitive
      wine_name_grape =~ /\b#{Regexp.escape(g)}\b/i
    end.map(&:titleize)   # normalise capitalisation

    # ------------------------------------------------------------------
    # Find / create a default producer (shared sink)
    # ------------------------------------------------------------------
    producer = Producer.unknown_producer

    # ------------------------------------------------------------------
    # 6️⃣  Find / create Wine  (now holds alcohol, price, closure)
    # ------------------------------------------------------------------
    wine = Wine.find_or_initialize_by(name: wine_name_grape)
    wine.producer = producer if wine.new_record?

    # CSV "Image URLs" (col 19) -> attach to the Wine via ActiveStorage.
    # The actual download+attach runs after wine.save! below (needs wine.id).

    # alcohol % (Wine attribute)
    wine.alcohol_percentage = alcohol_raw.delete("%").to_f if alcohol_raw.present?

    # price – stored in cents on Vintage only
    price_cents = nil
    if price_raw.present?
      dollars = price_raw.delete("$, ").to_f
      price_cents = (dollars * 100).round
    end

    # closure (Wine attribute) – normalize to allowed list
    normalized_closure = nil
    if closure_raw.present?
      normalized_closure = CLOSURE_MAP[closure_raw.downcase] || Wine::DEFAULT_CLOSURE
    end
    wine.closure = normalized_closure if normalized_closure

    wine.save! if wine.changed?

    # Queue the CSV image for attach AFTER the transaction commits.
    # (Network downloads must not run inside the DB transaction.)
    # The actual `attach_wine_image!` call is after the transaction block.
    if image_url_raw.present? && !wine.images.exists?
      unless $front_seed_pending_images.any? { |wid, _| wid == wine.id }
        $front_seed_pending_images << [wine.id, image_url_raw]
      end
    end

    # associate grapes (has_and_belongs_to_many :grapes)
    detected_grapes.each do |g_name|
      grape = Grape.find_or_create_by!(name: g_name)
      wine.grapes << grape unless wine.grapes.include?(grape)
    end

    # ------------------------------------------------------------------
    # 7️⃣  Find / create Vintage  (only year + price_cents)
    # ------------------------------------------------------------------
    next unless vintage_year

    vintage = Vintage.find_or_initialize_by(wine: wine, year: vintage_year)
    vintage.price_cents = price_cents if price_cents
    vintage.save! if vintage.changed?

    # ------------------------------------------------------------------
    # 8️⃣  Find or create the Review — UPSERT, no extra slug on reuse
    #      If the review already exists (same author + vintage) it is
    #      UPDATED with the CSV values. Slug auto-regenerates only when
    #      the title actually changes (model callback guard).
    #      NOTE: reviews table has no `tasted_at` column, so the CSV
    #      "Date Tasted" value is intentionally not parsed or stored.
    # ------------------------------------------------------------------
    published_at = nil
    begin
      published_at = Date.parse(publication_date) if publication_date.present?
    rescue ArgumentError, TypeError
      published_at = nil
    end
    # NOTE: the CSV "Date Tasted" column (e.g. "Sep26") has NO matching
    # column on Review (schema has drink_from/drink_to/drink_plus only),
    # so it is intentionally not parsed or stored. Add a `tasted_at`
    # migration if you need it in future.
    drink_from   = drink_from_raw.to_i if drink_from_raw =~ /\A\d{4}\z/
    drink_to     = drink_by_raw.gsub("+", "").to_i if drink_by_raw =~ /\A\d{4}\+?\z/
    drink_plus   = drink_by_raw.present? && drink_by_raw.end_with?("+")

    # Natural key: same author + same vintage.
    # The CSV has one review per vintage, so (user, vintage) is unique.
    review_attrs = {
      title:       wine_name_grape,
      comment:     review_body,
      status:      "published",
      source:      "wine_front",
      drink_from:  drink_from,
      drink_to:    drink_to,
      drink_plus:  drink_plus.nil? ? false : drink_plus
    }
    review_attrs[:score] = score if !score.nil?
    review_attrs[:published_at] = published_at if !published_at.nil?

    review = Review.find_by(user: author, vintage: vintage)
    if review.nil?
      review = Review.create!(
        { user: author, vintage: vintage }.merge(review_attrs)
      )
      $front_seed_created_reviews += 1
    else
      # UPSERT: overwrite CSV-driven fields with fresh values.
      # assign_attributes + save! so validations still run; slug only
      # changes when the title actually changed (model guard).
      review.assign_attributes(review_attrs)
      if review.changed?
        review.save!
        $front_seed_updated_reviews += 1
      end
    end

    # ------------------------------------------------------------------
    # 9️⃣  Article UPSERT when Categories mentions "articles"
    #      If the article already exists (same author + title) it is
    #      UPDATED with the CSV body. Links are ensured, never duplicated.
    # ------------------------------------------------------------------
    if categories_raw =~ /articles/i
      article = Article.find_by(user: author, title: wine_name_grape)
      if article.nil?
        article = Article.create!(
          title:        wine_name_grape,
          body:         review_body,
          user:         author,
          status:       "published",
          source:       "wine_front"
        )
        $front_seed_created_articles += 1
      else
        article_attrs = { body: review_body, status: "published", source: "wine_front" }
        article.assign_attributes(article_attrs)
        if article.changed?
          article.save!
          $front_seed_updated_articles += 1
        end
      end
      # Link article to the vintage (which links to the wine) — once only
      unless ArticleVintage.exists?(article: article, vintage: vintage)
        ArticleVintage.create!(article: article, vintage: vintage)
      end
      # Link article to the review — once only
      unless ArticleReview.exists?(article: article, review: review)
        ArticleReview.create!(article: article, review: review, status: "published")
      end
    end
  end
end

puts "✅  Front‑wine seed completed – #{Review.count} reviews, #{Wine.count} wines, #{Vintage.count} vintages."
puts "    Reviews: #{$front_seed_created_reviews} created, #{$front_seed_updated_reviews} updated."
puts "    Articles: #{$front_seed_created_articles} created, #{$front_seed_updated_articles} updated."

# ------------------------------------------------------------------
# Post-commit: attach queued Wine images (network I/O outside txn).
# Each entry is [wine_id, image_url_raw]. attach_wine_image! is
# idempotent — wines that already have an image are skipped.
# ------------------------------------------------------------------
puts "    🖼️  Attaching #{$front_seed_pending_images.size} queued wine images…"
$front_seed_pending_images.each do |wine_id, url|
  wine = Wine.find_by(id: wine_id)
  next if wine.nil?
  $front_seed_attached_images += 1 if attach_wine_image!(wine, url)
end
puts "    🖼️  Images attached this run: #{$front_seed_attached_images} (total Wine images: #{Image.where(imageable_type: 'Wine').count})."