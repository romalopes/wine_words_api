require "rails_helper"

RSpec.describe "Api::V1::ArticleProjects", type: :request do
  include Devise::Test::IntegrationHelpers

  def user_with_role(role_name, first_name, email)
    user = User.create!(first_name: first_name, email: email, password: "password123")
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  let(:reviewer) { user_with_role("Reviewer", "Article Project Reviewer", "article-project-reviewer@example.com") }
  let(:editor) { user_with_role("Editor", "Article Project Editor", "article-project-editor@example.com") }
  let(:other_reviewer) { user_with_role("Reviewer", "Other Reviewer", "other-article-project-reviewer@example.com") }
  let(:producer) { Producer.create!(name: "Article Project Producer") }

  def create_article_project(owner: reviewer, **attributes)
    ArticleProject.create!({ name: "Barolo feature", created_by: owner }.merge(attributes))
  end

  describe "authentication" do
    it "requires a signed-in user" do
      get "/api/v1/article_projects"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/article_projects" do
    it "assigns the authenticated reviewer as owner and persists nested joins" do
      sign_in reviewer

      post "/api/v1/article_projects", as: :json, params: {
        article_project: {
          name: "  Nebbiolo guide  ",
          created_by_id: editor.id,
          article_project_producers_attributes: [{ producer_id: producer.id, request_confirmed: true }]
        }
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Nebbiolo guide")
      expect(body.dig("created_by", "id")).to eq(reviewer.id)
      expect(body["article_project_producers"]).to include(hash_including("producer" => hash_including("id" => producer.id), "contacted" => true))
    end
  end

  describe "scoping" do
    it "limits a reviewer to Article Projects they created" do
      own_project = create_article_project(name: "Owned")
      hidden_project = create_article_project(owner: other_reviewer, name: "Hidden")
      sign_in reviewer

      get "/api/v1/article_projects"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |item| item["id"] }).to eq([own_project.id])

      get "/api/v1/article_projects/#{hidden_project.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "allows an editor to list Article Projects created by other users" do
      article_project = create_article_project(owner: other_reviewer)
      sign_in editor

      get "/api/v1/article_projects"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |item| item["id"] }).to include(article_project.id)
    end
  end

  describe "GET /api/v1/article_projects/lookup" do
    it "returns only linkable records in the compact picker contract" do
      own_article = Article.create!(title: "Nebbiolo notes", status: "draft", user: reviewer)
      foreign_article = Article.create!(title: "Nebbiolo hidden", status: "draft", user: other_reviewer)
      wine = Wine.create!(name: "Nebbiolo", producer: producer)
      vintage = Vintage.create!(wine: wine, year: 2022)
      own_review = Review.create!(title: "Nebbiolo review", status: "draft", score: 90, user: reviewer, vintage: vintage)
      Review.create!(title: "Nebbiolo foreign", status: "draft", score: 89, user: other_reviewer, vintage: vintage)
      sign_in reviewer

      get "/api/v1/article_projects/lookup", params: { kind: "article", q: "nebbiolo" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |row| row["id"] }).to eq([own_article.id])

      get "/api/v1/article_projects/lookup", params: { kind: "vintage", q: "nebbiolo", producer_id: producer.id }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(hash_including("id" => vintage.id, "wine_name" => "Nebbiolo", "producer_id" => producer.id))

      get "/api/v1/article_projects/lookup", params: { kind: "review", q: "nebbiolo" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).map { |row| row["id"] }).to eq([own_review.id])
    end
  end

  describe "PATCH /api/v1/article_projects/:id" do
    it "requires lock_version and responds with a conflict to a stale update" do
      article_project = create_article_project
      sign_in reviewer

      patch "/api/v1/article_projects/#{article_project.id}", as: :json,
            params: { article_project: { name: "No version" } }
      expect(response).to have_http_status(:unprocessable_entity)

      article_project.update!(name: "Changed elsewhere")
      patch "/api/v1/article_projects/#{article_project.id}", as: :json,
            params: { article_project: { name: "Stale", lock_version: 0 } }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]).to include("Reload")
    end

    it "rejects a nested join ID from a different Article Project" do
      own_project = create_article_project
      other_project = create_article_project(owner: other_reviewer)
      foreign_join = other_project.article_project_producers.create!(producer: producer)
      sign_in reviewer

      patch "/api/v1/article_projects/#{own_project.id}", as: :json, params: {
        article_project: {
          lock_version: own_project.lock_version,
          article_project_producers_attributes: [{ id: foreign_join.id, contacted: true }]
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(foreign_join.reload.contacted).to be(false)
    end
  end

  describe "notebooks and review drafts" do
    let(:wine) { Wine.create!(name: "Barolo", producer: producer) }
    let(:vintage) { Vintage.create!(wine: wine, year: 2022) }
    let(:article_project) { create_article_project }
    let!(:project_vintage) { article_project.article_project_vintages.create!(vintage: vintage) }

    it "manages a notebook and creates an independently editable linked draft review" do
      sign_in reviewer

      post "/api/v1/article_projects/#{article_project.id}/article_project_vintages/#{project_vintage.id}/notebooks",
           as: :json,
           params: { article_project_notebook: { title: "Tasting notes", content: "Cherry and rose petals" } }

      expect(response).to have_http_status(:created)
      notebook = JSON.parse(response.body)
      notebook_id = notebook.fetch("id")
      expect(notebook.fetch("lock_version")).to eq(0)

      post "/api/v1/article_projects/#{article_project.id}/article_project_vintages/#{project_vintage.id}/notebooks/#{notebook_id}/review",
           as: :json

      expect(response).to have_http_status(:created)
      review_id = JSON.parse(response.body).fetch("id")
      review = Review.find(review_id)
      expect(review).to have_attributes(title: "Tasting notes", comment: "Cherry and rose petals", status: "draft", score: 80, vintage: vintage, user: reviewer)
      expect(article_project.reviews).to include(review)

      patch "/api/v1/article_projects/#{article_project.id}/article_project_vintages/#{project_vintage.id}/notebooks/#{notebook_id}",
            as: :json,
            params: { article_project_notebook: { content: "Updated notebook content", lock_version: notebook.fetch("lock_version") } }

      expect(response).to have_http_status(:ok)
      expect(review.reload.comment).to eq("Cherry and rose petals")
    end

    it "returns a recoverable conflict for a stale notebook update" do
      notebook = project_vintage.article_project_notebooks.create!(title: "Tasting notes", content: "Original")
      sign_in reviewer

      notebook.update!(content: "Saved elsewhere")
      patch "/api/v1/article_projects/#{article_project.id}/article_project_vintages/#{project_vintage.id}/notebooks/#{notebook.id}",
            as: :json,
            params: { article_project_notebook: { content: "Stale browser content", lock_version: 0 } }

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).fetch("error")).to include("Reload")
      expect(notebook.reload.content).to eq("Saved elsewhere")
    end

    it "does not allow another reviewer to manage the project's notebooks" do
      notebook = project_vintage.article_project_notebooks.create!(title: "Private notes", content: "Do not copy")
      sign_in other_reviewer

      post "/api/v1/article_projects/#{article_project.id}/article_project_vintages/#{project_vintage.id}/notebooks/#{notebook.id}/review",
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(Review.count).to eq(0)
    end
  end
end