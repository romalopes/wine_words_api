require "rails_helper"

RSpec.describe Like, type: :model do
  def create_user(suffix)
    User.create!(first_name: "Like User #{suffix} #{SecureRandom.hex(2)}",
                 email: "like-#{suffix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  let(:user_a) { create_user("a") }
  let(:user_b) { create_user("b") }
  let(:producer) { Producer.create!(name: "Like Producer #{SecureRandom.hex(3)}") }
  let(:wine) { Wine.create!(name: "Like Wine #{SecureRandom.hex(3)}", color: "Red", producer: producer) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2019) }
  let(:review) do
    Review.create!(vintage: vintage, user: user_a, title: "Like Review #{SecureRandom.hex(3)}",
                   score: 90, status: "published")
  end
  let(:article) { Article.create!(title: "Like Article #{SecureRandom.hex(3)}", user: user_a, status: "published") }

  it "belongs to a user and a polymorphic likeable" do
    like = Like.create!(user: user_a, likeable: wine)
    expect(like.user).to eq(user_a)
    expect(like.likeable).to eq(wine)
    expect(wine.likes).to include(like)
  end

  it "is valid across all three likeable types for the same user" do
    expect(Like.create!(user: user_a, likeable: wine)).to be_persisted
    expect(Like.create!(user: user_a, likeable: review)).to be_persisted
    expect(Like.create!(user: user_a, likeable: article)).to be_persisted
  end

  it "allows different users to like the same resource" do
    Like.create!(user: user_a, likeable: wine)
    expect(Like.create!(user: user_b, likeable: wine)).to be_persisted
  end

  it "rejects a duplicate like from the same user on the same resource" do
    Like.create!(user: user_a, likeable: wine)
    dup = Like.new(user: user_a, likeable: wine)
    expect(dup).not_to be_valid
    expect { dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "maintains the counter cache on create and destroy" do
    expect { Like.create!(user: user_a, likeable: wine) }.to change { wine.reload.likes_count }.by(1)
    expect { Like.create!(user: user_b, likeable: review) }.to change { review.reload.likes_count }.by(1)
    expect { Like.create!(user: user_a, likeable: article) }.to change { article.reload.likes_count }.by(1)

    like = Like.find_by!(user: user_a, likeable: wine)
    expect { like.destroy }.to change { wine.reload.likes_count }.by(-1)
  end

  it "removes likes when the likeable is destroyed" do
    Like.create!(user: user_a, likeable: wine)
    expect { wine.destroy }.to change(Like, :count).by(-1)
  end

  it "removes likes when the user is destroyed" do
    Like.create!(user: user_a, likeable: wine)
    expect { user_a.destroy }.to change(Like, :count).by(-1)
    expect(wine.reload.likes_count).to eq(0)
  end
end
