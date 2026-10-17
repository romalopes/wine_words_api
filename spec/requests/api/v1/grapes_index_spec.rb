require "rails_helper"

# Request specs for Api::V1::GrapesController#index.
#
# The list path bulk-computes wines_count / producers_count with two grouped
# COUNT queries (grapes_list_json). The previous per-record `.size` calls
# fired one COUNT per grape — 40 per page at per_page=20 — which against the
# remote dev DB cost ~8 s per request (and ~40 s for the legacy no-param
# full-list branch, which shares grapes_list_json).
RSpec.describe "Api::V1::Grapes", type: :request do
  describe "GET /api/v1/grapes" do
    def link_wine(grape, name)
      producer = Producer.create!(name: "#{name} Estate")
      wine = Wine.create!(name: name, color: "White", producer: producer)
      wine.grapes << grape
      wine
    end

    it "returns a paginated envelope with the requested page size" do
      3.times { |i| Grape.create!(name: "Index Grape #{i}") }

      get "/api/v1/grapes", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["page"]).to eq(1)
      expect(body["per_page"]).to eq(2)
      expect(body["items"].length).to eq(2)
      expect(body["total_count"]).to eq(3)
      expect(body["total_pages"]).to eq(2)

      get "/api/v1/grapes", params: { page: 2, per_page: 2 }
      second = JSON.parse(response.body)
      expect(second["page"]).to eq(2)
      expect(second["items"].length).to eq(1)

      # Pages never overlap.
      overlap = body["items"].map { |g| g["slug"] } &
                second["items"].map { |g| g["slug"] }
      expect(overlap).to be_empty
    end

    it "computes counts in bulk without per-grape COUNTs and embeds no wines" do
      grape = Grape.create!(name: "Counted Grape", color: "red")
      empty = Grape.create!(name: "Uncounted Grape")
      producer = Producer.create!(name: "Counted Estate")
      producer.grapes << grape
      link_wine(grape, "Counted Wine")

      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get "/api/v1/grapes", params: { page: 1, per_page: 20 }
      end

      expect(response).to have_http_status(:ok)
      items = JSON.parse(response.body)["items"]

      counted = items.find { |g| g["slug"] == grape.slug }
      expect(counted["wines_count"]).to eq(1)
      expect(counted["producers_count"]).to eq(1)
      expect(counted).not_to have_key("wines")

      uncounted = items.find { |g| g["slug"] == empty.slug }
      expect(uncounted["wines_count"]).to eq(0)
      expect(uncounted["producers_count"]).to eq(0)

      # Regression guard: the old serializer fired one of these per grape.
      expect(queries.grep(/COUNT\(\*\) FROM "wines" INNER JOIN "wine_grapes"/)).to be_empty
      expect(queries.grep(/COUNT\(\*\) FROM "producers" INNER JOIN "producer_grapes"/)).to be_empty
    end

    it "orders by wine / producer counts when sort is requested" do
      a = Grape.create!(name: "Sort A")
      b = Grape.create!(name: "Sort B")
      c = Grape.create!(name: "Sort C")
      2.times { |i| link_wine(b, "B Wine #{i}") } # b: 2 wines
      link_wine(a, "A Wine")                      # a: 1 wine
      3.times { |i| Producer.create!(name: "C Estate #{i}").grapes << c } # c: 3 producers
      Producer.create!(name: "B Estate").grapes << b                     # b: 1 producer

      get "/api/v1/grapes", params: { sort: "wines_count", per_page: 20 }
      expect(response).to have_http_status(:ok)
      items = JSON.parse(response.body)
      expect(items.map { |g| g["slug"] }).to eq([b.slug, a.slug, c.slug])
      expect(items.map { |g| g["wines_count"] }).to eq([2, 1, 0])

      get "/api/v1/grapes", params: { sort: "producers_count", per_page: 20 }
      expect(response).to have_http_status(:ok)
      items = JSON.parse(response.body)
      expect(items.map { |g| g["slug"] }).to eq([c.slug, b.slug, a.slug])
      expect(items.map { |g| g["producers_count"] }).to eq([3, 1, 0])
    end

    it "keeps the relevance default when sort is missing or unknown" do
      get "/api/v1/grapes", params: { per_page: 20 }
      expect(response).to have_http_status(:ok)

      get "/api/v1/grapes", params: { sort: "bogus", per_page: 20 }
      expect(response).to have_http_status(:ok)
    end

    it "is public (no auth required)" do
      get "/api/v1/grapes"
      expect(response).to have_http_status(:ok)
    end
  end
end
