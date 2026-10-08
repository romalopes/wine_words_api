# db/seeds/substract_articles_seed.rb
# Seed data for importing articles & reviews from Kasia Sobiesiak's Substack
# - Fetches the RSS feed (contains every published post)
# - For each entry, loads the public article page to obtain the full HTML body,
#   lead image, publication date and description.
# - Creates/updates either an Article or a Review record (Review when the title
#   starts with "Review:" or contains " Review ").
# - Uses the existing Imageable concern to attach the lead image.
# - Idempotent: records are matched by slug; re‑running the seed only updates.

require 'open-uri'
require 'nokogiri'

# -------------------------------------------------------------------------
# Helpers
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

def article_urls_from_rss(rss_doc)
  rss_doc.css('item').map { |item| item.at('link')&.text&.strip }.compact.uniq
end

def parse_article_page(doc, url)
  # Title
  title = (doc.at('h1.post-title') || doc.at('title'))&.text&.strip || 'Untitled'

  # Lead image (og:image)
  lead_image_url = doc.at('meta[property="og:image"]')&.[]('content')

  # Publication date
  published_at = nil
  %w[time meta[property="article:published_time"] meta[property="article:modified_time"]].each do |sel|
    el = doc.at(sel)
    dt   = el&.[]('datetime') || el&.[]('content')
    next unless dt
    published_at = DateTime.parse(dt) rescue nil
    break if published_at
  end

  # Description / abstract
  abstract = (doc.at('meta[name="description"]') || doc.at('meta[property="og:description"]'))&.[]('content')&.strip

  # Full body HTML → plain text
  body_el = doc.at('.body.markup') || doc.at('.available-content .body') || doc.at('article .body')
  body_html = body_el&.inner_html || ''
  body_text = Nokogiri::HTML(body_html).text.strip

  abstract = body_text[0, 200] if abstract.blank? && body_text.present?

  is_review = title.start_with?('Review:') || title.include?(' Review ')

  # Very small category inference (can be expanded later)
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

def unique_slug(base, klass)
  candidate = base.presence || 'post'
  slug = candidate
  i = 2
  while klass.where(slug: slug).where.not(id: nil).exists?
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

# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------
puts '🚀  Substack import starting…'

rss_doc = fetch_and_parse('https://kasiasobiesiak.substack.com/feed')
abort('❌  RSS feed unavailable') unless rss_doc

urls = article_urls_from_rss(rss_doc)
puts "📋  #{urls.size} posts found in feed."

user = fallback_user
created = updated = failed = 0

urls.each_with_index do |url, idx|
  print "[#{idx + 1}/#{urls.size}] #{url} … "
  doc = fetch_and_parse(url)
  if doc.nil?
    puts '❌ fetch failed'
    failed += 1
    next
  end

  data = parse_article_page(doc, url)

  klass   = data[:is_review] ? Review : Article
  slug    = unique_slug(data[:title].parameterize, klass)
  record  = klass.find_by(slug: slug) || klass.new(slug: slug)

  # Common attributes
  common = {
    title: data[:title],
    status: 'published',
    published_at: data[:published_at],
    user: user
  }

  if data[:is_review]
    # Review‑specific
    year = data[:title][/\b(20\d{2})\b/]&.to_i
    vintage = year ? Vintage.find_by(year: year) : nil
    vintage ||= Vintage.first # fallback
    record.assign_attributes(common.merge(
      comment: data[:body_text],
      score: 90,                 # placeholder – could be parsed from body later
      vintage: vintage
    ))
    # Category for review
    if data[:category_name]
      cat = Category.find_or_create_by!(name: data[:category_name], for_review: true) { |c| c.slug = data[:category_name].parameterize }
      record.category = cat
    end
  else
    # Article‑specific
    record.assign_attributes(common.merge(
      abstract: data[:abstract],
      body: data[:body_text]
    ))
    if data[:category_name]
      cat = Category.find_or_create_by!(name: data[:category_name], for_article: true) { |c| c.slug = data[:category_name].parameterize }
      record.category = cat
    end
  end

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

puts "\n🎉  Import finished"
puts "   🆕 Created: #{created}"
puts "   🔄 Updated: #{updated}"
puts "   ❌ Failed:  #{failed}"
puts "   📊 Total:   #{urls.size}"
