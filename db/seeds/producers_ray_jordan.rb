# frozen_string_literal: true

# Imports the producers listed by Ray Jordan Wine, their supplied metadata, and
# their winery-logo images.
#
# Usage:
#   bin/rails runner db/seeds/producers_ray_jordan.rb
#
# Optional environment variables:
#   RAY_JORDAN_DRY_RUN=true  Fetch and parse pages without changing the database.
#   RAY_JORDAN_LIMIT=5       Import only the first N producers (useful for testing).
#   RAY_JORDAN_ONLY="3 Drops,Corymbia"  Import only the named producers.
#   SEED_AVOID_IMAGES=true   Create/update producers but do not download images.
#
# This seed is intentionally idempotent: producers are found by name, regions
# are linked only once, and an image is downloaded only when the producer does
# not already have one.

require "cgi"
require "nokogiri"
require "open-uri"
require "set"
require "uri"

RAY_JORDAN_BASE_URL = "https://www.rayjordanwine.com.au"
RAY_JORDAN_PRODUCERS_URL = "#{RAY_JORDAN_BASE_URL}/pages/producers"
RAY_JORDAN_USER_AGENT = "Mozilla/5.0 (compatible; WineWordsRayJordanSeed/1.0)"
RAY_JORDAN_REQUEST_RETRIES = 3
RAY_JORDAN_REQUEST_DELAY = 0.35
RAY_JORDAN_MULTI_REGION_SEPARATOR = ","
RAY_JORDAN_NON_REGION_VALUES = ["Australia, France, China, USA"].freeze
RAY_JORDAN_REGION_ALIASES = {
  "Great Soutern" => "Great Southern"
}.freeze
RAY_JORDAN_HTML_ACCEPT = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
RAY_JORDAN_IMAGE_ACCEPT = "image/webp,image/apng,image/png,image/jpeg,image/gif,image/*;q=0.8,*/*;q=0.5"

ray_jordan_dry_run = ENV.fetch("RAY_JORDAN_DRY_RUN", "false") == "true"
ray_jordan_skip_images = ENV.fetch("SEED_AVOID_IMAGES", "false") == "true"
ray_jordan_limit = ENV.fetch("RAY_JORDAN_LIMIT", "").to_i
ray_jordan_only_names = ENV.fetch("RAY_JORDAN_ONLY", "").split(",").map(&:squish).reject(&:blank?).to_set

def ray_jordan_absolute_url(value)
  return if value.blank?

  decoded = CGI.unescapeHTML(value.strip)
  return "https:#{decoded}" if decoded.start_with?("//")
  return decoded if decoded.start_with?("http://", "https://")

  URI.join(RAY_JORDAN_BASE_URL, decoded).to_s
end

def ray_jordan_not_found_error?(error)
  error.message.match?(/\b404\b/)
end

def ray_jordan_fetch(url, accept: RAY_JORDAN_HTML_ACCEPT)
  RAY_JORDAN_REQUEST_RETRIES.times do |attempt|
    begin
      response = URI.open(
        url,
        "User-Agent" => RAY_JORDAN_USER_AGENT,
        "Accept" => accept,
        read_timeout: 30,
        open_timeout: 15
      )
      return response unless block_given?

      begin
        return yield(response)
      ensure
        response.close
      end
    rescue OpenURI::HTTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise if ray_jordan_not_found_error?(e)
      raise if attempt == RAY_JORDAN_REQUEST_RETRIES - 1

      wait_seconds = (attempt + 1) * 2
      puts "  ⚠️  Fetch failed (#{e.class}: #{e.message}); retrying #{url} in #{wait_seconds}s"
      sleep wait_seconds
    end
  end
end

def ray_jordan_fetch_html(url)
  ray_jordan_fetch(url) { |response| Nokogiri::HTML(response.read) }
end

def ray_jordan_largest_srcset_url(image)
  return if image.blank?

  srcset = image["srcset"].to_s
  return ray_jordan_absolute_url(image["src"]) if srcset.blank?

  largest = srcset.split(",").filter_map do |entry|
    url, width = entry.strip.split(/\s+/, 2)
    next if url.blank?

    [url, width.to_s[/\d+/].to_i]
  end.max_by { |(_, width)| width }

  ray_jordan_absolute_url(largest&.first || image["src"])
end

def ray_jordan_parse_index
  document = ray_jordan_fetch_html(RAY_JORDAN_PRODUCERS_URL)

  producers = document.css('a[href^="/collections/"]').filter_map do |link|
    # Producer cards have direct img + span children. This excludes collection
    # links in the site navigation, including the "Wine Review 2027" card.
    image = link.xpath("./img").first
    name = link.xpath("./span").first&.text&.squish
    image_url = ray_jordan_absolute_url(image&.[]("src"))
    href = link["href"]

    next if name.blank? || href.blank? || image_url.blank?

    {
      name: CGI.unescapeHTML(name),
      collection_path: href,
      thumbnail_url: image_url
    }
  end

  producers.uniq { |producer| producer[:collection_path] }
end

def ray_jordan_parse_producer_page(collection_path, fallback_name:, thumbnail_url:)
  document = ray_jordan_fetch_html(ray_jordan_absolute_url(collection_path))
  hero = document.at_css(".winery-hero__row")
  raise "Winery hero was not found" if hero.blank?

  text = hero.at_css(".winery-hero__text")
  name = text&.at_css("h1.heading-md")&.text&.squish.presence || fallback_name
  region_value = text&.at_css("h4")&.text&.squish
  website = text&.at_css("p.winery-hero__web a")&.[]("href")&.strip
  # description = text&.at_css(".metafield-multi_line_text_field")&.text&.squish
  hero_logo_url = ray_jordan_largest_srcset_url(hero.at_css(".winery-hero__logo img"))

  {
    name: CGI.unescapeHTML(name),
    # description: CGI.unescapeHTML(description.to_s).presence,
    website: ray_jordan_absolute_url(website),
    region_names: ray_jordan_region_names(region_value),
    image_url: hero_logo_url || thumbnail_url
  }
end

def ray_jordan_region_names(raw_value)
  normalized = CGI.unescapeHTML(raw_value.to_s).squish
  return [] if normalized.blank? || RAY_JORDAN_NON_REGION_VALUES.include?(normalized)

  normalized.split(RAY_JORDAN_MULTI_REGION_SEPARATOR)
            .map(&:squish)
            .map { |name| RAY_JORDAN_REGION_ALIASES.fetch(name, name) }
            .reject(&:blank?)
            .uniq
end

def ray_jordan_australia
  Country.find_by("lower(name) = ?", "australia") || Country.find_or_create_by!(code: "AU") do |country|
    country.name = "Australia"
    country.continent = "Oceania"
  end
end

def ray_jordan_region_for(name, country)
  existing = Region.find_by(name: name, country: country)
  return existing if existing

  # Wilyabrup is a recognised Margaret River subregion but is not currently in
  # db/seeds/regions.rb. Keep its hierarchy accurate when it is encountered.
  if name == "Wilyabrup"
    parent = Region.find_by!(name: "Margaret River", country: country)
    return Region.create!(
      name: name,
      country: country,
      parent: parent,
      is_appellation: true,
      is_state: false
    )
  end

  parent = Region.find_by(name: "South West Australia", country: country)
  puts "  ⚠️  Creating unmapped Ray Jordan region #{name.inspect} under #{parent&.name || country.name}"
  Region.create!(
    name: name,
    country: country,
    parent: parent,
    is_appellation: true,
    is_state: false
  )
end

def ray_jordan_remove_obsolete_region_aliases!(producer, country)
  RAY_JORDAN_REGION_ALIASES.each do |obsolete_name, canonical_name|
    next unless producer.regions.exists?(name: obsolete_name, country: country)
    next unless producer.regions.exists?(name: canonical_name, country: country)

    obsolete_region = producer.regions.find_by!(name: obsolete_name, country: country)
    producer.regions.delete(obsolete_region)
    puts "  ↳ Removed obsolete region alias #{obsolete_name.inspect}"
  end
end

def ray_jordan_attach_image!(producer, *image_urls)
  return if producer.images.exists?

  image_urls.compact.uniq.each do |image_url|
    response = nil
    begin
      response = ray_jordan_fetch(image_url, accept: RAY_JORDAN_IMAGE_ACCEPT)
      content_type = response.content_type.to_s.split(";").first
      unless Image::ALLOWED_CONTENT_TYPES.include?(content_type)
        puts "  ⚠️  Skipping unsupported image type #{content_type.inspect}: #{image_url}"
        next
      end

      uri = URI.parse(image_url)
      filename = File.basename(uri.path).presence || "#{producer.slug}.jpg"
      image = producer.images.build(primary: true)
      image.file.attach(io: response, filename: filename, content_type: content_type)
      image.save!
      puts "  🖼️  Attached #{filename}"
      return
    rescue StandardError => e
      puts "  ⚠️  Could not attach image #{image_url}: #{e.class}: #{e.message}"
    ensure
      response&.close if response.respond_to?(:close)
    end
  end
end

puts "Ray Jordan producer import#{ray_jordan_dry_run ? ' (dry run)' : ''}"
puts "Fetching producer index: #{RAY_JORDAN_PRODUCERS_URL}"

ray_jordan_index_producers = ray_jordan_parse_index
if ray_jordan_only_names.any?
  ray_jordan_index_producers.select! { |producer| ray_jordan_only_names.include?(producer[:name]) }
end
if ray_jordan_limit.positive?
  ray_jordan_index_producers = ray_jordan_index_producers.first(ray_jordan_limit)
end

raise "No Ray Jordan producers were found on the index page" if ray_jordan_index_producers.empty?

puts "Found #{ray_jordan_index_producers.size} producers."

ray_jordan_country = ray_jordan_australia unless ray_jordan_dry_run
ray_jordan_counts = Hash.new(0)
ray_jordan_failures = []

ray_jordan_index_producers.each_with_index do |index_producer, index|
  print "[#{index + 1}/#{ray_jordan_index_producers.size}] #{index_producer[:name]}"

  begin
    details = begin
      ray_jordan_parse_producer_page(
        index_producer[:collection_path],
        fallback_name: index_producer[:name],
        thumbnail_url: index_producer[:thumbnail_url]
      )
    rescue OpenURI::HTTPError => e
      raise unless ray_jordan_not_found_error?(e)

      puts " — detail page unavailable; importing index-card data"
      {
        name: index_producer[:name],
        description: nil,
        website: nil,
        region_names: [],
        image_url: index_producer[:thumbnail_url]
      }
    end
    region_display = details[:region_names].presence&.join(", ") || "no region"
    puts " — #{region_display}" unless details[:description].nil? && details[:website].nil? && details[:region_names].empty?

    if ray_jordan_dry_run
      ray_jordan_counts[:parsed] += 1
      sleep RAY_JORDAN_REQUEST_DELAY
      next
    end

    producer = Producer.find_or_initialize_by(name: details[:name])
    producer.slug = index_producer[:collection_path].delete_prefix("/collections/")
    producer.email = "#{producer.slug.tr('-', '_')}@winewords.com.au" if producer.email.blank? || !producer.email.match?(URI::MailTo::EMAIL_REGEXP)
    producer.website = details[:website] if details[:website].present?
    # producer.description = details[:description] if details[:description].present?
    producer.country = ray_jordan_country
    producer.save!
    created = producer.previously_new_record?

    details[:region_names].each do |region_name|
      region = ray_jordan_region_for(region_name, ray_jordan_country)
      producer.regions << region unless producer.regions.exists?(id: region.id)
    end
    ray_jordan_remove_obsolete_region_aliases!(producer, ray_jordan_country)

    ray_jordan_attach_image!(producer, details[:image_url], index_producer[:thumbnail_url]) unless ray_jordan_skip_images
    ray_jordan_counts[created ? :created : :updated] += 1
  rescue StandardError => e
    puts "  ⚠️  Failed: #{e.class}: #{e.message}"
    ray_jordan_failures << { name: index_producer[:name], error: "#{e.class}: #{e.message}" }
  ensure
    sleep RAY_JORDAN_REQUEST_DELAY
  end
end

puts "\nRay Jordan import complete."
puts "  Parsed: #{ray_jordan_counts[:parsed]}" if ray_jordan_dry_run
puts "  Created: #{ray_jordan_counts[:created]}" unless ray_jordan_dry_run
puts "  Updated: #{ray_jordan_counts[:updated]}" unless ray_jordan_dry_run
puts "  Failures: #{ray_jordan_failures.size}"
ray_jordan_failures.each { |failure| puts "    - #{failure[:name]}: #{failure[:error]}" }