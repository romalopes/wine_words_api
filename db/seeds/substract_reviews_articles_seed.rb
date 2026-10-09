# db/seeds/substract_reviews_articles_seed.rb
# --------------------------------------------------------------
# Seed that imports a *fixed* list of Substack posts (articles & reviews)
# written by Kasia Sobiesiak.
#
# * Detects a review when the title starts with "Review:" or contains " Review ".
# * For reviews the title format is expected to be:
#       Review: <Wine Name> <Vintage>
#   e.g.  "Review: Aline Beauné Santenay 1er Cru Beaurepaire 2022"
#   The script extracts the wine name and the 4‑digit year, finds/creates the
#   Wine and Vintage records, links a Grape if the last word of the wine name
#   matches an existing Grape, and creates a Review (score = 90, comment = full
#   body text, category.for_review = true).
# * **When a brand‑new Wine is created, the review's lead image is also attached
#   to that Wine (via the Imageable concern).**
# * For normal articles an Article record is created (abstract, body,
#   category.for_article = true).
# * Both models use the existing `Imageable` concern to attach the lead image.
# * Slug uniqueness is guaranteed with a `Model.where(slug:).exists?` loop.
# * A temporary fallback user is created if no user exists.
# --------------------------------------------------------------

require 'open-uri'
require 'nokogiri'
require 'securerandom'

# -------------------------------------------------------------------------
# Helper methods (kept from the previous seed – they already work)
# -------------------------------------------------------------------------
def fetch_and_parse(url)
  begin
    URI.open(url,
             'User-Agent' => 'Mozilla/5.0 (compatible; WineWordsSeed/1.0)',
             read_timeout: 30) do |resp|
      # Try XML first (RSS), fall back to HTML
      begin
        doc = Nokogiri::XML(resp.read)
        raise 'XML parsing failed' if doc.errors.any? { |e| e.fatal? }
        doc
      rescue
        resp.rewind if resp.respond_to?(:rewind)
        Nokogiri::HTML(resp.read)
      end
    end
  rescue => e
    puts "  ⚠️  fetch failed #{url}: #{e.message}"
    nil
  end
end

def unique_slug(base, klass)
  candidate = base.presence || 'post'
  slug = candidate
  i = 2
  while klass.where(slug: slug).exists?
    slug = "#{candidate}-#{i}"
    i += 1
  end
  slug
end

def fallback_user
  User.where(email: "kasia@mywineadviser.com.au").first || User.where(email: "romalopes@yahoo.com.br").first || User.first ||
    User.create!(email: "seed_fallback_#{SecureRandom.hex(4)}@example.com",
                 password: SecureRandom.hex(16))
end

# Attach an image to any Imageable record (Article, Review, Wine, …)
def attach_image(record, image_url)
  return if record.images.any? || image_url.blank?

  begin
    file = URI.open(image_url)
    img  = Image.new(imageable: record)
    img.file.attach(io: file, filename: File.basename(image_url))
    img.save!
    print ' 🖼️'
  rescue => e
    print " ⚠️img:#{e.message}"
  end
end

# Convert plain URLs in a text into markdown links: [url](url)
def linkify(text)
  return text if text.blank?
  # Match http(s)://... not preceded by '(' (i.e., not already inside markdown parentheses)
  text.gsub(%r{(https?://S+)}) do |url|
    # Avoid double‑linking if already wrapped in markdown or html
    next url if url.start_with?('[') || url.start_with?('<')
    "[#{url}](#{url})"
  end
end

# -------------------------------------------------------------------------
# Parse a single article page – returns a hash with all needed data
# -------------------------------------------------------------------------
def parse_article_page(doc, url)
  title = (doc.at('h1.post-title') || doc.at('title'))&.text&.strip || 'Untitled'

  lead_image_url = doc.at('meta[property="og:image"]')&.[]('content')

  published_at = nil
  %w[time meta[property="article:published_time"] meta[property="article:modified_time"]].each do |sel|
    el = doc.at(sel)
    dt = el&.[]('datetime') || el&.[]('content')
    next unless dt
    published_at = DateTime.parse(dt) rescue nil
    break if published_at
  end

  abstract = (doc.at('meta[name="description"]') || doc.at('meta[property="og:description"]'))&.[]('content')&.strip

  body_el   = doc.at('.body.markup') || doc.at('.available-content .body') || doc.at('article .body')
  body_html = body_el&.inner_html || ''

  # Convert HTML <a href="...">text</a> into Markdown links before extracting plain text
  fragment = Nokogiri::HTML::fragment(body_html)
  fragment.css('a').each do |a|
    href = a['href']
    next unless href
    link_text = a.text.strip
    markdown = if link_text.empty? || link_text == href
                 "[#{href}](#{href})"
               else
                 "[#{link_text}](#{href})"
               end
    a.replace(markdown)
  end
  body_text = fragment.text.strip
  body_text = linkify(body_text)

  abstract = body_text[0, 200] if abstract.blank? && body_text.present?
  abstract = linkify(abstract) if abstract.present?

  is_review = title.start_with?('Review:') || title.include?(' Review ')

  # Very small category inference (kept from the old seed)
  category_name =
    if is_review
      'Review'
    elsif title.match?(/Trade|Industry|Champagne|Sparkling/i)
      'Tasting'
    elsif title.match?(/Travel|Trip|Visit/i)
      'Travel'
    elsif title.match?(/Interview|Conversation/i)
      'Interview'
    else
      'Article'
    end

  {
    title: title,
    abstract: abstract,
    body_text: body_text,
    lead_image_url: lead_image_url,
    published_at: published_at,
    category_name: category_name,
    is_review: is_review,
    source_url: url
  }
end

# -------------------------------------------------------------------------
# Extract wine name, vintage and possible grape from a review title
# -------------------------------------------------------------------------
def parse_review_title(title)
  # Expected pattern: "Review: <Wine Name> <YYYY>"
  if (m = title.match(/^Review:\s*(.+?)\s+(20\d{2})\s*$/i))
    raw_name = m[1].strip
    year     = m[2].to_i

    # Try to guess a grape – last word of the name that matches a Grape record
    possible_grape_word = raw_name.split.last
    grape = Grape.find_by('lower(name) = ?', possible_grape_word.downcase)

    { wine_name: raw_name, vintage_year: year, grape: grape }
  else
    # Fallback – whole title without the leading "Review:"; no vintage / grape
    { wine_name: title.sub(/^Review:\s*/i, '').strip, vintage_year: nil, grape: nil }
  end
end

# -------------------------------------------------------------------------
# Parse structured review details from the full body text
# Expected lines like:
#   Rated : 94 Points
#   Tasted : Jun26
#   Alcohol : 12.5%
#   Price : $169
#   Closure : Cork
#   Drink : 2026 - 2033+
# -------------------------------------------------------------------------
def parse_review_details(body)
  details = {}
  body.each_line do |line|
    line = line.strip
    next if line.empty?

    case line
    when /^Rated\s*:\s*(\d+)\s*Points?/i
      details[:score] = $1.to_i
    when /^Tasted\s*:\s*(.+)/i
      details[:tasted] = $1.strip
    when /^Alcohol\s*:\s*([\d.]+)%/i
      details[:alcohol] = $1.to_f
    when /^Price\s*:\s*\$(\d+)/i
      details[:price_cents] = $1.to_i * 100
    when /^Closure\s*:\s*(.+)/i
      details[:closure] = $1.strip
    when /^Drink\s*:\s*(\d{4})\s*-\s*(\d{4})\+?/i
      details[:drink_from] = $1.to_i
      details[:drink_to]   = $2.to_i
      details[:drink_extended] = line.include?('+')
    end
  end
  details
end

# -------------------------------------------------------------------------
# Main – iterate over the explicit URL list you gave
# -------------------------------------------------------------------------
puts '🚀  Substack import (fixed URL list) starting…'

URLS = [
  'https://kasiasobiesiak.substack.com/p/review-raga-sangiovese-2025',
  'https://kasiasobiesiak.substack.com/p/kumeu-river-wines-at-rays-road-vineyard',
  'https://kasiasobiesiak.substack.com/p/drinks-trade-champagne-and-sparkling',
  'https://kasiasobiesiak.substack.com/p/review-aline-beaune-santenay-1er',
  'https://kasiasobiesiak.substack.com/p/review-emidio-pepe-montepulciano',
  'https://kasiasobiesiak.substack.com/p/review-giaconda-chardonnay-2022',
  'https://kasiasobiesiak.substack.com/p/austria-otw-single-vineyard-summitthe',
  'https://kasiasobiesiak.substack.com/p/the-loire-valley-muscadet-sevre-et',
  'https://kasiasobiesiak.substack.com/p/marsala-marco-de-bartoli-vecchio',
  'https://kasiasobiesiak.substack.com/p/review-frederic-cossard-la-chassornade',
  'https://kasiasobiesiak.substack.com/p/review-williams-selyem-weir-vineyard',
  'https://kasiasobiesiak.substack.com/p/review-williams-selyem-williams-selyem',
  'https://kasiasobiesiak.substack.com/p/review-mac-forbes-woori-yallock-ferguson',
  'https://kasiasobiesiak.substack.com/p/review-collector-tiger-tiger-chardonnay',
  'https://kasiasobiesiak.substack.com/p/review-byrne-farm-chardonnay-2023',
  'https://kasiasobiesiak.substack.com/p/review-domaine-naturaliste-purus',
  'https://kasiasobiesiak.substack.com/p/review-quealy-feri-maris-chardonnay',
  'https://kasiasobiesiak.substack.com/p/kerri-greens-hickson-chardonnay-2024',
  'https://kasiasobiesiak.substack.com/p/review-vignerons-schmolzer-and-brown-f07',
  'https://kasiasobiesiak.substack.com/p/review-byrne-farm-chardonnay-2024',
  'https://kasiasobiesiak.substack.com/p/review-byrne-farm-single-barrel-chardonnay',
  'https://kasiasobiesiak.substack.com/p/review-howard-park-allingham-chardonnay',
  'https://kasiasobiesiak.substack.com/p/review-domaine-naturaliste-artus',
  'https://kasiasobiesiak.substack.com/p/review-vignerons-schmolzer-and-brown',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-series-do-it-differently',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-series-harmonious-match',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-series-comfort-drops',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-series-emerging-summer',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-series-primavera-of',
  'https://kasiasobiesiak.substack.com/p/jura-a-conversation-with-wink-lorch',
  'https://kasiasobiesiak.substack.com/p/from-cinematography-to-winemaking',
  'https://kasiasobiesiak.substack.com/p/review-handpicked-capella-vineyard',
  'https://kasiasobiesiak.substack.com/p/review-krug-grande-cuvee-171eme-edition',
  'https://kasiasobiesiak.substack.com/p/sandrone-vite-talin-2017',
  'https://kasiasobiesiak.substack.com/p/review-champagne-salon-cuvee-s-le',
  'https://kasiasobiesiak.substack.com/p/review-dirler-cade-grand-cru-kessler',
  'https://kasiasobiesiak.substack.com/p/review-foreign-friends-black-springs',
  'https://kasiasobiesiak.substack.com/p/yangarra-high-sands-grenache-celebrating',
  'https://kasiasobiesiak.substack.com/p/pastis',
  'https://kasiasobiesiak.substack.com/p/review-michael-hall-sang-de-pigeon-b5a',
  'https://kasiasobiesiak.substack.com/p/review-whisson-lake-monopole-pinot',
  'https://kasiasobiesiak.substack.com/p/aussie-in-bourgogne-a-conversation',
  'https://kasiasobiesiak.substack.com/p/etna-on-augustus-rest-day-15082025',
  'https://kasiasobiesiak.substack.com/p/tyrrells-vat-9-shiraz-vertical-tasting',
  'https://kasiasobiesiak.substack.com/p/the-new-old-bastard-kaesler-wines',
  'https://kasiasobiesiak.substack.com/p/a-lost-letter-from-orange',
  'https://kasiasobiesiak.substack.com/p/mornington-peninsula-chardonnay-and',
  'https://kasiasobiesiak.substack.com/p/snippet-of-tasmanian-sparkling',
  'https://kasiasobiesiak.substack.com/p/australia-and-new-zealand-wine-tasting',
  'https://kasiasobiesiak.substack.com/p/winter-visit-to-champagne-larmandier',
  'https://kasiasobiesiak.substack.com/p/rippon-retrospective-new-release',
  'https://kasiasobiesiak.substack.com/p/snapshot-of-mudgee-august-2023',
  'https://kasiasobiesiak.substack.com/p/howard-park-wines-past-present-and',
  'https://kasiasobiesiak.substack.com/p/the-story-of-stonewell-celebrating',
  'https://kasiasobiesiak.substack.com/p/mchenry-hohnen-single-vineyard-release',
  'https://kasiasobiesiak.substack.com/p/mchenry-hohnen-single-vineyard-release',
  'https://kasiasobiesiak.substack.com/p/hunter-valley-backstage-and-backvintage',
  'https://kasiasobiesiak.substack.com/p/mount-pleasant-museum-release-showcase',
  'https://kasiasobiesiak.substack.com/p/tumbarumba-chardonnay-benchmark-blind',
  'https://kasiasobiesiak.substack.com/p/penfolds-st-henri-mini-vertical-1991',
  'https://kasiasobiesiak.substack.com/p/wynns-john-riddoch-and-black-label'
]

user = fallback_user
created = updated = failed = 0

URLS.each_with_index do |url, idx|
  print "[#{idx + 1}/#{URLS.size}] #{url} … "
  doc = fetch_and_parse(url)

  if doc.nil?
    puts '❌ fetch failed'
    failed += 1
    next
  end

  data = parse_article_page(doc, url)

  # For reviews we store the title *without* the leading "Review:" prefix.
  review_title = data[:is_review] ? data[:title].sub(/^Review:\s*/i, '').strip : data[:title]

  klass = data[:is_review] ? Review : Article
  slug  = unique_slug(review_title.parameterize, klass)
  record = klass.find_by(slug: slug) || klass.new(slug: slug)

  # -------------------------------------------------------------
  # Common attributes for both Article and Review
  # -------------------------------------------------------------

  common = {
    title: review_title,
    status: 'draft',
    published_at: data[:published_at],
    user: user
  }

  if data[:is_review]
    # ------------------- REVIEW SPECIFIC -------------------------
    parsed = parse_review_title(data[:title])

    # ---- Wine -------------------------------------------------
    wine = Wine.find_by('lower(name) = ?', parsed[:wine_name].downcase)
    wine_created = false
    unless wine
      wine = Wine.create!(
        name: parsed[:wine_name],
        color: 'White',               # safe default – can be edited later
        closure: Wine::DEFAULT_CLOSURE,
        alcohol_percentage: Wine::DEFAULT_ALCOHOL_PERCENTAGE,
        volume_ml: Wine::DEFAULT_VOLUME,
        producer: Producer.first || Producer.create!(name: 'Unknown Producer')
      )
      wine_created = true
      puts "   🍷 created wine “#{wine.name}”"
    end

    # ---- Attach the review's lead image to the *new* wine ----------
    if wine_created
      attach_image(wine, data[:lead_image_url])
    end

    # ---- Grape (if we could guess one) -------------------------
    if parsed[:grape]
      wine.grapes << parsed[:grape] unless wine.grapes.include?(parsed[:grape])
      wine.save!
      puts "   🍇 linked grape “#{parsed[:grape].name}”"
    end

    # ---- Vintage -----------------------------------------------
    vintage = nil
    if parsed[:vintage_year]
      vintage = Vintage.find_by(wine: wine, year: parsed[:vintage_year])
      vintage ||= Vintage.create!(wine: wine, year: parsed[:vintage_year])
      puts "   📅 vintage #{vintage.year} ready"
    else
      vintage = Vintage.first   # ultimate fallback – should not happen for real reviews
    end

    # ---- Parse review details from body ----
    details = parse_review_details(data[:body_text])

    # ---- Update wine with alcohol & closure if present ----
    wine_updated = false
    if details[:alcohol] && wine.alcohol_percentage != details[:alcohol]
      wine.alcohol_percentage = details[:alcohol]
      wine_updated = true
    end
    if details[:closure] && Wine::CLOSURES.include?(details[:closure]) && wine.closure != details[:closure]
      wine.closure = details[:closure]
      wine_updated = true
    end
    wine.save! if wine_updated

    # ---- Update vintage price if present ----
    if details[:price_cents]
      vintage.price_cents = details[:price_cents]
      vintage.save!
    end

    # ---- Prepare review comment (body + optional drinking window note) ----
    comment = data[:body_text].dup
    if details[:drink_extended]
      comment << "\n\nDrinking window can be extended (+)"
    end

    # ---- Determine review published_at from tasted if possible ----
    review_published_at = data[:published_at]
    if details[:tasted]
      begin
        # Expect format like "Jun26"
        review_published_at = DateTime.strptime(details[:tasted], "%b%y")
      rescue
        # ignore parse errors
      end
    end

    # ---- Build / update Review ---------------------------------
    record.assign_attributes(common.merge(
      comment: comment,
      score: details[:score] || 90,
      vintage: vintage,
      drink_from: details[:drink_from],
      drink_to: details[:drink_to],
      published_at: review_published_at
    ))

    # Category for review (for_review: true)
    if data[:category_name]
      cat = Category.find_or_create_by!(name: data[:category_name], for_review: true) do |c|
        c.slug = data[:category_name].parameterize
      end
      record.category = cat
    end
  else
    # ------------------- ARTICLE SPECIFIC -----------------------
    record.assign_attributes(common.merge(
      abstract: data[:abstract],
      body: data[:body_text]
    ))

    if data[:category_name]
      cat = Category.find_or_create_by!(name: data[:category_name], for_article: true) do |c|
        c.slug = data[:category_name].parameterize
      end
      record.category = cat
    end
  end

  # -------------------------------------------------------------
  # Persist & attach lead image (to the Article / Review)
  # -------------------------------------------------------------
  begin
    if record.new_record?
      record.save!
      created += 1
      print '🆕'
    else
      record.save!
      updated += 1
      print '🔄'
    end
    attach_image(record, data[:lead_image_url])
    puts " ✅ #{data[:title]}"
  rescue => e
    puts " ❌ #{e.message}"
    failed += 1
  end
end

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
puts "\n🎉  Import finished"
puts "   🆕 Created: #{created}"
puts "   🔄 Updated: #{updated}"
puts "   ❌ Failed:  #{failed}"
puts "   📊 Total:   #{URLS.size}"
