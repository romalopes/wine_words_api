require "rails_helper"

RSpec.describe "Api::V1::Comments", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(suffix)
    User.create!(user_name: "API Comment #{suffix} #{SecureRandom.hex(2)}",
                 email: "api-comment-#{suffix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  # Reader is a real base role, so start from a paying-style account instead of
  # juggling role assignments in every example. Role rows are created on demand
  # (the test database is not seeded), same convention as the other request specs.
  def create_reader(suffix = "reader")
    user = create_user(suffix)
    user.roles << Role.find_or_create_by!(name: "Reader")
    user
  end

  def create_with_role(role_name, suffix = nil)
    user = create_user(suffix || role_name.downcase)
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  let(:owner) { create_reader("owner") }
  let(:other) { create_reader("other") }
  let(:guest) { create_user("guest") }
  let(:producer) { Producer.create!(name: "API Comment Producer #{SecureRandom.hex(3)}") }
  let(:wine) { Wine.create!(name: "API Comment Wine #{SecureRandom.hex(3)}", color: "Red", producer: producer) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) do
    Review.create!(vintage: vintage, user: owner, title: "API Comment Review #{SecureRandom.hex(3)}",
                   score: 88, status: "published")
  end
  let(:article) { Article.create!(title: "API Comment Article #{SecureRandom.hex(3)}", user: owner, status: "published") }

  shared_examples "a commentable endpoint" do |path_for, record_name|
    let(:record) { send(record_name) }
    let(:path) { path_for.call(record) }

    it "rejects unauthenticated POST" do
      post path, params: { comment: { body: "Anonymous" } }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a Guest account" do
      sign_in guest
      post path, params: { comment: { body: "Guest comment" } }
      expect(response).to have_http_status(:forbidden)
      expect(record.comments.count).to eq(0)
    end

    it "lets a Reader comment" do
      sign_in other
      post path, params: { comment: { body: "Reader comment" } }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["body"]).to eq("Reader comment")
      expect(body["author"]["id"]).to eq(other.id)
      expect(body["parent_id"]).to be_nil
      expect(record.comments.count).to eq(1)
    end

    it "rejects an empty body" do
      sign_in other
      post path, params: { comment: { body: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "never comments on behalf of another user" do
      sign_in other
      post path, params: { comment: { body: "Mine" }, user_id: owner.id }
      expect(response).to have_http_status(:created)
      expect(Comment.where(commentable: record).pluck(:user_id)).to eq([ other.id ])
    end

    it "lists the thread with replies nested under their parent" do
      sign_in other
      post path, params: { comment: { body: "Top level" } }
      parent = Comment.order(:id).last

      sign_in owner
      post "/api/v1/comments/#{parent.id}/replies", params: { comment: { body: "A reply" } }

      get path
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["comments_count"]).to eq(1)
      expect(body["comments"].first["body"]).to eq("Top level")
      expect(body["comments"].first["replies"].map { |r| r["body"] }).to eq([ "A reply" ])
    end

    it "returns 404 for a missing resource" do
      sign_in other
      post "#{path}-missing-999999", params: { comment: { body: "Nope" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "wines" do
    include_examples "a commentable endpoint",
                     ->(wine) { "/api/v1/wines/#{wine.slug}/comments" }, :wine
  end

  describe "reviews" do
    include_examples "a commentable endpoint",
                     ->(review) { "/api/v1/reviews/#{review.slug}/comments" }, :review
  end

  describe "articles" do
    include_examples "a commentable endpoint",
                     ->(article) { "/api/v1/articles/#{article.slug}/comments" }, :article
  end
  describe "roles" do
    it "lets Reviewer, Editor and Admin comment" do
      [ "Reviewer", "Editor", "Admin" ].each do |role_name|
        commenter = create_with_role(role_name)
        sign_in commenter
        post "/api/v1/wines/#{wine.slug}/comments", params: { comment: { body: "From #{role_name}" } }
        expect(response).to have_http_status(:created), "expected #{role_name} to be able to comment"
        sign_out commenter
      end
    end

    it "lets a Reviewer on the free subscription comment (privileged roles ignore the plan)" do
      reviewer = create_with_role("Reviewer", "reviewerfree")
      # No Reader role and no paid plan — the privileged role alone grants it.
      expect(reviewer.role_names).to include("Reviewer")
      expect(reviewer.role_names).not_to include("Reader")
      sign_in reviewer
      post "/api/v1/wines/#{wine.slug}/comments", params: { comment: { body: "Reviewer here" } }
      expect(response).to have_http_status(:created)
    end
  end

  describe "replies" do
    let!(:parent) { Comment.create!(user: owner, commentable: wine, body: "Top level.") }

    it "requires authentication" do
      post "/api/v1/comments/#{parent.id}/replies", params: { comment: { body: "Hi" } }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a Guest" do
      sign_in guest
      post "/api/v1/comments/#{parent.id}/replies", params: { comment: { body: "Hi" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "derives the commentable from the parent" do
      sign_in other
      post "/api/v1/comments/#{parent.id}/replies", params: { comment: { body: "Agreed." } }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["commentable_type"]).to eq("Wine")
      expect(body["commentable_id"]).to eq(wine.id)
      expect(body["parent_id"]).to eq(parent.id)
      expect(parent.replies.count).to eq(1)
    end

    it "refuses a reply to a reply" do
      reply = Comment.create!(user: other, commentable: wine, parent: parent, body: "First reply.")
      sign_in owner
      post "/api/v1/comments/#{reply.id}/replies", params: { comment: { body: "Too deep." } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(reply.replies.count).to eq(0)
    end

    it "returns 404 for an unknown parent comment" do
      sign_in other
      post "/api/v1/comments/999999/replies", params: { comment: { body: "Hi" } }
      expect(response).to have_http_status(:not_found)
    end
  end
  describe "the polymorphic bypass" do
    it "ignores a client-supplied commentable_type and keeps the comment on the URL's resource" do
      sign_in other
      post "/api/v1/wines/#{wine.slug}/comments",
           params: { comment: { body: "Wine comment", commentable_type: "User", commentable_id: owner.id } }
      expect(response).to have_http_status(:created)
      comment = Comment.order(:id).last
      expect(comment.commentable_type).to eq("Wine")
      expect(comment.commentable_id).to eq(wine.id)
    end

    it "derives a reply's commentable from the parent, so a cross-resource reply is impossible" do
      foreign = Comment.create!(user: owner, commentable: article, body: "On an article.")
      sign_in other
      post "/api/v1/comments/#{foreign.id}/replies", params: { comment: { body: "Sneaky" } }
      expect(response).to have_http_status(:created)
      reply = Comment.order(:id).last
      expect(reply.commentable_type).to eq("Article")
      expect(reply.commentable_id).to eq(article.id)
    end

    it "refuses a model-level parent that belongs to another commentable" do
      foreign = Comment.create!(user: owner, commentable: article, body: "On an article.")
      invalid = Comment.new(user: other, commentable: wine, parent: foreign, body: "Sneaky")
      expect(invalid).not_to be_valid
    end
  end

  describe "editing and deleting" do
    let!(:comment) { Comment.create!(user: owner, commentable: wine, body: "Original.") }

    it "lets the author edit their own comment" do
      sign_in owner
      patch "/api/v1/comments/#{comment.id}", params: { comment: { body: "Edited." } }
      expect(response).to have_http_status(:ok)
      expect(comment.reload.body).to eq("Edited.")
    end

    it "refuses to let another user edit it" do
      sign_in other
      patch "/api/v1/comments/#{comment.id}", params: { comment: { body: "Hijacked." } }
      expect(response).to have_http_status(:forbidden)
      expect(comment.reload.body).to eq("Original.")
    end

    it "refuses a Guest" do
      sign_in guest
      patch "/api/v1/comments/#{comment.id}", params: { comment: { body: "Guest edit." } }
      expect(response).to have_http_status(:forbidden)
    end

    it "validates the edited body" do
      sign_in owner
      patch "/api/v1/comments/#{comment.id}", params: { comment: { body: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "lets the author soft delete, keeping the row" do
      sign_in owner
      delete "/api/v1/comments/#{comment.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["deleted"]).to be(true)
      expect(comment.reload).to be_deleted
      expect(Comment.exists?(comment.id)).to be(true)
    end

    it "refuses a delete by another ordinary user" do
      sign_in other
      delete "/api/v1/comments/#{comment.id}"
      expect(response).to have_http_status(:forbidden)
      expect(comment.reload).not_to be_deleted
    end

    it "lets an Admin delete another user's comment" do
      admin = create_with_role("Admin")
      sign_in admin
      delete "/api/v1/comments/#{comment.id}"
      expect(response).to have_http_status(:ok)
      expect(comment.reload).to be_deleted
    end

    it "lets an Editor delete another user's comment" do
      editor = create_with_role("Editor")
      sign_in editor
      delete "/api/v1/comments/#{comment.id}"
      expect(response).to have_http_status(:ok)
      expect(comment.reload).to be_deleted
    end

    it "does not let a Reviewer moderate another user's comment" do
      reviewer = create_with_role("Reviewer")
      sign_in reviewer
      delete "/api/v1/comments/#{comment.id}"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for an unknown comment" do
      sign_in owner
      delete "/api/v1/comments/999999"
      expect(response).to have_http_status(:not_found)
    end
  end
  describe "visibility of drafts" do
    it "returns 404 when commenting on a draft review the user cannot see" do
      draft = Review.create!(vintage: vintage, user: other, title: "Draft #{SecureRandom.hex(3)}",
                             score: 80, status: "draft")
      sign_in owner
      post "/api/v1/reviews/#{draft.slug}/comments", params: { comment: { body: "Sneak" } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when commenting on a draft article the user cannot see" do
      draft = Article.create!(title: "Draft #{SecureRandom.hex(3)}", user: other, status: "draft")
      sign_in owner
      post "/api/v1/articles/#{draft.slug}/comments", params: { comment: { body: "Sneak" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "payload" do
    it "marks the current user's own comment as editable and somebody else's as not" do
      Comment.create!(user: owner, commentable: wine, body: "Mine.")
      Comment.create!(user: other, commentable: wine, body: "Theirs.")
      sign_in owner
      get "/api/v1/wines/#{wine.slug}/comments"
      body = JSON.parse(response.body)
      flags = body["comments"].map { |c| [ c["body"], c["editable"], c["deletable"] ] }
      expect(flags).to include([ "Mine.", true, true ])
      expect(flags).to include([ "Theirs.", false, false ])
    end

    it "gives an Admin full moderation flags on another user's comment" do
      Comment.create!(user: other, commentable: wine, body: "Theirs.")
      admin = create_with_role("Admin")
      sign_in admin
      get "/api/v1/wines/#{wine.slug}/comments"
      comment = JSON.parse(response.body)["comments"].first
      expect(comment["editable"]).to be(true)
      expect(comment["deletable"]).to be(true)
    end

    it "renders a deleted comment as a tombstone without its text" do
      comment = Comment.create!(user: other, commentable: wine, body: "Spam.")
      comment.soft_delete!
      sign_in owner
      get "/api/v1/wines/#{wine.slug}/comments"
      body = JSON.parse(response.body)
      expect(body["comments_count"]).to eq(1)
      expect(body["comments"].first["body"]).to eq(Comment::DELETED_BODY_PLACEHOLDER)
      expect(body["comments"].first["deleted"]).to be(true)
    end
  end
end