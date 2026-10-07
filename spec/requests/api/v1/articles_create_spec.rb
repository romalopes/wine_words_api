require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Articles create", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:reviewer) do
    user = User.create!(
      first_name: "Article Reviewer",
      email: "article-reviewer@example.com",
      password: "password123",
    )
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end

  it "creates a draft without optional associations while audit logging is enabled" do
    sign_in reviewer

    expect {
      post "/api/v1/articles", params: {
        article: {
          title: "Project draft",
          abstract: "",
          body: "",
          status: "draft",
          category_ids: [],
          tag_names: "",
          vintage_ids: [],
          review_ids: [],
          producer_ids: [],
        },
      }, as: :json
    }.to change(Article, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)).to include(
      "title" => "Project draft",
      "status" => "draft",
    )
  end
end