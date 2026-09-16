module Authentication
  # Supplies the provider's JSON Web Key Set to the `jwt` gem's key finder.
  #
  # Key sets are public documents that providers rotate rarely, so they are
  # cached — Rails.cache is a memory store in development, solid_cache in
  # production and a null store in tests, so caching is real where it matters
  # and transparent under test.
  #
  # The gem's KeyFinder asks for an invalidation (`invalidate: true`) when a
  # token arrives with a kid it has not seen before: that is the standard key
  # rotation dance and is our cue to refetch once.
  class Jwks
    CACHE_TTL = 1.hour

    def initialize(url)
      @url = url
    end

    # Loader Proc for the `jwks:` decode option. The gem calls it with the
    # token's kid (`{ kid: "..." }`) and later with `invalidate: true`.
    def loader
      lambda do |options = {}|
        document(invalidate: options[:invalidate] == true)
      end
    end

    def document(invalidate: false)
      Rails.cache.delete(cache_key) if invalidate
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { fetch_document }
    end

    private

    attr_reader :url

    def cache_key
      "authentication/jwks/#{Digest::SHA256.hexdigest(url)}"
    end

    def fetch_document
      document = HttpClient.get_json(url)
      unless document.is_a?(Hash) && document["keys"].is_a?(Array)
        raise Authentication::Error.new(
          "Unexpected response from the identity provider.",
          code: :provider_error, status: :bad_gateway
        )
      end
      document
    end
  end
end