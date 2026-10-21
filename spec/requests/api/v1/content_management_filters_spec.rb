require "rails_helper"
require "devise"

RSpec.describe "Api::V1 content management filters", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:manager) { User.create!(first_name: "Manager", email: "manager@example.com", password: "password123") }
  let!(:author) { User.create!(first_name: "Author", email: "author@example.com", password: "password123") }
  let!(:country) { Country.find_or_create_by!(code: Producer::DEFAULT_COUNTRY_CODE) { |c| c.name = "Australia" } }
  let!(:producer) { Producer.create!(name: "Filter Winery", country: country) }
  let!(:wine) { Wine.create!(name: "Filter Red", producer: producer, color: "Red") }
  let!(:vintage) { Vintage.create!(wine: wine, year: 2022) }

  before { manager.add_role("Editor") }

  def create_review(title, user: author, status: "draft", deadline: nil)
    record = Review.create!(title:, vintage:, user:, score: 90, status:, deadline:)
    record.update_column(:deadline, nil) if deadline.nil?
    record
  end

  def create_article(title, user: author, status: "draft", deadline: nil)
    record = Article.create!(title:, user:, status:, deadline:)
    record.update_column(:deadline, nil) if deadline.nil?
    record
  end

  shared_examples "management filters" do |path, content_type|
    def create_content(content_type, title, **attributes)
      content_type == :review ? create_review(title, **attributes) : create_article(title, **attributes)
    end

    it "combines mine, status, deadline and search without widening visibility" do
      matching = create_content(content_type, "Estate Shiraz draft", user: manager, deadline: Date.current - 1)
      create_content(content_type, "Other author draft", deadline: Date.current - 1)
      create_content(content_type, "My published", user: manager, status: "published", deadline: Date.current - 1)

      sign_in manager
      get path, params: { page: 1, scope: "mine", status: "draft", deadline: "overdue", query: "shiraz" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("items").map { |item| item.fetch("id") }).to eq([matching.id])
    end

    it "treats today as due soon rather than overdue and excludes published and archived rows" do
      overdue = create_content(content_type, "Overdue", user: manager, deadline: Date.current - 1)
      today = create_content(content_type, "Today", user: manager, deadline: Date.current)
      create_content(content_type, "Published", user: manager, status: "published", deadline: Date.current - 1)
      create_content(content_type, "Archived", user: manager, status: "archived", deadline: Date.current - 1)

      sign_in manager
      get path, params: { page: 1, deadline: "overdue" }
      overdue_ids = JSON.parse(response.body).fetch("items").map { |item| item.fetch("id") }
      expect(overdue_ids).to include(overdue.id)
      expect(overdue_ids).not_to include(today.id)

      get path, params: { page: 1, deadline: "due_soon" }
      expect(JSON.parse(response.body).fetch("items").map { |item| item.fetch("id") }).to include(today.id)
    end

    it "filters null deadlines and sorts by deadline" do
      no_deadline = create_content(content_type, "No deadline", user: manager, deadline: nil)
      later = create_content(content_type, "Later", user: manager, deadline: Date.current + 3)
      sooner = create_content(content_type, "Sooner", user: manager, deadline: Date.current + 1)

      sign_in manager
      get path, params: { page: 1, deadline: "none" }
      expect(JSON.parse(response.body).fetch("items").map { |item| item.fetch("id") }).to include(no_deadline.id)

      get path, params: { page: 1, sort: "deadline_asc" }
      ids = JSON.parse(response.body).fetch("items").map { |item| item.fetch("id") }
      expect(ids.index(sooner.id)).to be < ids.index(later.id)
    end
  end

  describe "reviews" do
    include_examples "management filters", "/api/v1/reviews", :review
  end

  describe "articles" do
    include_examples "management filters", "/api/v1/articles", :article
  end
end