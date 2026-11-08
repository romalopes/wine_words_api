# Uses local Ollama (llama3.2:3b) to interpret natural language wine
# search queries into structured parameters that drive DB lookups.
#
# Flow:
#   1. User types "something bold and fruity from Australia"
#   2. This service asks Ollama to extract structured params
#   3. The extracted params drive the existing pg_trgm database queries
#
# This is completely free — Ollama runs locally, no API keys or billing.
require "net/http"
require "json"

class LlmSearchService
  OLLAMA_BASE = ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
  MODEL       = ENV.fetch("OLLAMA_MODEL", "llama3.2:3b")
  TIMEOUT     = 8  # seconds — enough for a small model on Apple Silicon

  SYSTEM_PROMPT = <<~PROMPT
    You are a wine search query interpreter. Given a user's free-text
    description of what they want to find, extract structured parameters
    that can be used to search a wine database.

    Return ONLY a JSON object with these keys (no extra text):
    {
      "name_hints": ["list", "of", "specific", "wine", "names", "to", "search"],
      "region_hints": ["list", "of", "region", "keywords"],
      "color": "Red", "White", "Rosé", "Sparkling", or null,
      "style_notes": ["list", "of", "style/flavor", "keywords"]
    }

    Rules:
    - If the user mentions a specific wine by name (e.g. "Penfolds"), put it in name_hints
    - If the user mentions a region (e.g. "Burgundy"), put it in region_hints
    - If the user mentions color (e.g. "red"), put it in color
    - If the user says "bold and fruity", put ["bold", "fruity"] in style_notes
    - Be generous — extract ALL relevant terms, even partial ones
    - For style_notes: map synonyms (e.g. "full bodied" → "full", "powerful" → "bold")
  PROMPT

  # @param query [String] The user's natural-language search text
  # @return [Hash] with keys: name_hints, region_hints, color, style_notes, raw_query
  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return empty_result if @query.blank?

    llm_result = extract_params_from_llm
    build_result(llm_result)
  rescue StandardError => e
    Rails.logger.warn("[LlmSearchService] Ollama unavailable (#{e.message}), returning fallback")
    fallback_result
  end

  private

  def empty_result
    { name_hints: [], region_hints: [], color: nil, style_notes: [], raw_query: "" }
  end

  def fallback_result
    # When Ollama is down, fall back to the raw query as both name and region hint
    { name_hints: [ @query ], region_hints: [ @query ], color: nil, style_notes: [], raw_query: @query }
  end

  def build_result(llm_json)
    {
      name_hints:    Array(llm_json["name_hints"]).reject(&:blank?).map(&:strip),
      region_hints:  Array(llm_json["region_hints"]).reject(&:blank?).map(&:strip),
      color:         llm_json["color"],
      style_notes:   Array(llm_json["style_notes"]).reject(&:blank?).map(&:strip),
      raw_query:     @query
    }
  end

  def extract_params_from_llm
    uri  = URI("#{OLLAMA_BASE}/api/generate")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    payload = {
      model:  MODEL,
      prompt: "#{SYSTEM_PROMPT}\n\nUser search: \"#{@query}\"",
      stream: false
    }

    response = http.post(uri.path, payload.to_json, { "Content-Type" => "application/json" })

    result = JSON.parse(response.body)
    raw_response = result["response"].to_s

    # Extract JSON from the response — the model may include markdown fences
    json_match = raw_response.match(/\{.*\}/m)
    if json_match
      JSON.parse(json_match[0])
    else
      fallback_result
    end
  rescue JSON::ParserError
    Rails.logger.warn("[LlmSearchService] Could not parse LLM response: #{raw_response}")
    fallback_result
  end
end
