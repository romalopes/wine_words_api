require "rails_helper"

RSpec.describe Comment, type: :model do
  def create_user(suffix)
    User.create!(first_name: "Comment User #{suffix} #{SecureRandom.hex(2)}",
                 email: "comment-#{suffix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  let(:user_a) { create_user("a") }
  let(:user_b) { create_user("b") }
  let(:producer) { Producer.create!(name: "Comment Producer #{SecureRandom.hex(3)}") }
  let(:wine) { Wine.create!(name: "Comment Wine #{SecureRandom.hex(3)}", color: "Red", producer: producer) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2021) }
  let(:review) do
    Review.create!(vintage: vintage, user: user_a, title: "Comment Review #{SecureRandom.hex(3)}",
                   score: 88, status: "published")
  end
  let(:article) { Article.create!(title: "Comment Article #{SecureRandom.hex(3)}", user: user_a, status: "published") }

  it "belongs to a user and a polymorphic commentable" do
    comment = Comment.create!(user: user_a, commentable: wine, body: "Lovely wine.")
    expect(comment.user).to eq(user_a)
    expect(comment.commentable).to eq(wine)
    expect(wine.comments).to include(comment)
  end

  it "works for all three commentable types" do
    expect(Comment.create!(user: user_a, commentable: wine, body: "On the wine.")).to be_persisted
    expect(Comment.create!(user: user_a, commentable: review, body: "On the review.")).to be_persisted
    expect(Comment.create!(user: user_a, commentable: article, body: "On the article.")).to be_persisted
  end

  it "requires a body" do
    comment = Comment.new(user: user_a, commentable: wine, body: "  ")
    expect(comment).not_to be_valid
    expect(comment.errors[:body]).to be_present
  end

  it "rejects a body longer than the maximum" do
    comment = Comment.new(user: user_a, commentable: wine, body: "a" * (Comment::MAX_BODY_LENGTH + 1))
    expect(comment).not_to be_valid
  end

  it "rejects a commentable type outside the whitelist" do
    comment = Comment.new(user: user_a, commentable: user_b, body: "Not allowed here.")
    expect(comment).not_to be_valid
    expect(comment.errors[:commentable_type]).to be_present
  end

  describe "replies" do
    let(:parent) { Comment.create!(user: user_a, commentable: wine, body: "Top level.") }

    it "creates a reply linked to its parent" do
      reply = Comment.create!(user: user_b, commentable: wine, parent: parent, body: "Agreed.")
      expect(reply).to be_reply
      expect(reply.parent).to eq(parent)
      expect(parent.replies).to include(reply)
    end

    it "refuses a parent that is itself a reply (threads stay one level deep)" do
      reply = Comment.create!(user: user_b, commentable: wine, parent: parent, body: "Agreed.")
      nested = Comment.new(user: user_a, commentable: wine, parent: reply, body: "Too deep.")
      expect(nested).not_to be_valid
      expect(nested.errors[:parent]).to be_present
    end

    it "refuses a parent belonging to a different commentable" do
      foreign = Comment.create!(user: user_a, commentable: review, body: "On a review.")
      cross = Comment.new(user: user_b, commentable: article, parent: foreign, body: "Cross.")
      expect(cross).not_to be_valid
      expect(cross.errors[:parent]).to be_present
    end
  end

  describe "soft delete" do
    let(:parent) { Comment.create!(user: user_a, commentable: wine, body: "Top level.") }
    let!(:reply) { Comment.create!(user: user_b, commentable: wine, parent: parent, body: "Agreed.") }

    it "hides the body but keeps the row" do
      parent.soft_delete!
      expect(parent.reload).to be_deleted
      expect(parent.display_body).to eq(Comment::DELETED_BODY_PLACEHOLDER)
      expect(Comment.exists?(parent.id)).to be(true)
    end

    it "cascades to the replies" do
      parent.soft_delete!
      expect(reply.reload).to be_deleted
    end

    it "keeps deleted comments in the thread as tombstones and exposes them via visible_comments" do
      other = Comment.create!(user: user_b, commentable: wine, body: "Still here.")
      parent.soft_delete!

      # The thread preserves the structure — the deleted comment is still a node,
      # rendered as "[Comment deleted]" rather than removed.
      expect(wine.comment_thread.map(&:id)).to contain_exactly(parent.id, other.id)
      expect(wine.comment_thread.find { |c| c.id == parent.id }.display_body)
        .to eq(Comment::DELETED_BODY_PLACEHOLDER)

      # visible_comments is the "live only" view.
      expect(wine.visible_comments).to contain_exactly(other)
    end
  end

  it "removes comments when the commentable is destroyed" do
    Comment.create!(user: user_a, commentable: wine, body: "Doomed.")
    expect { wine.destroy }.to change(Comment, :count).by(-1)
  end

  it "removes comments and their replies when the user is destroyed" do
    parent = Comment.create!(user: user_a, commentable: wine, body: "Doomed.")
    Comment.create!(user: user_a, commentable: wine, parent: parent, body: "Doomed too.")
    expect { user_a.destroy }.to change(Comment, :count).by(-2)
  end
end