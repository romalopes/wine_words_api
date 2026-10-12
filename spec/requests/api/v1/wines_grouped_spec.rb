require "rails_helper"

RSpec.describe "Wine list query efficiency", type: :request do
  let(:producer) { Producer.create!(name: "List Estate") }

  def make_wine(name)
    wine = Wine.create!(name: name, color: "Red", producer: producer)
    image = wine.images.create!
    image.file.attach(io: File.open(Rails.root.join("spec/fixtures/files/logo.png")), filename: "logo.png", content_type: "image/png")
    wine
  end

  def capture_queries(path, params = {})
    queries = []
    callback = ->(*args) { queries << args.last[:sql] unless args.last[:cached] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get path, params: params
    end
    expect(response).to have_http_status(:ok)
    queries
  end

  it "caps category cards while preserving totals and multi-category membership" do
    wines = 3.times.map { |i| make_wine("Wine #{i}") }
    category = Category.create!(name: "Featured")
    second = Category.create!(name: "Classic")
    wines.each { |wine| wine.categories << category }
    wines.first.categories << second
    make_wine("Uncategorised Wine")

    capture_queries("/api/v1/wines/grouped", { per_group: 1 })
    groups = JSON.parse(response.body).index_by { |group| group["category"] }
    expect(groups["Featured"]["count"]).to eq(3)
    expect(groups["Featured"]["wines"].map { |wine| wine["name"] }).to eq(["Wine 0"])
    expect(groups["Classic"]["count"]).to eq(1)
    expect(groups["Uncategorised"]["count"]).to eq(1)
    expect(groups["Featured"]["wines"].first["images"].size).to eq(1)
  end

  ["/api/v1/wines/grouped", "/api/v1/wines"].each do |path|
    it "batches image and category queries for #{path}" do
      category = Category.create!(name: "Featured")
      3.times { |i| make_wine("Wine #{i}").categories << category }
      queries = capture_queries(path, { page: 1, per_page: 2 })
      %w[images active_storage_attachments active_storage_blobs categories].each do |table|
        expect(queries.grep(/FROM "#{table}"/).size).to be <= 1
      end
    end
  end
end
