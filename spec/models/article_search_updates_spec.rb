require "rails_helper"

RSpec.describe Article, type: :model do
  it "refreshes searchable text after editing a reloaded article" do
    user = User.create!(first_name: "Author", email: "index-author@example.com", password: "password123")
    article = Article.create!(title: "Original heading", user: user)
    article = Article.find(article.id)
    article.update!(title: "Zinfandel vineyard")
    expect(Article.text_search("zinfandel").pluck(:id)).to include(article.id)

    tag = Tag.create!(name: "Nebbiolo")
    article.tags << tag
    article.save!
    expect(Article.text_search("nebbiolo").pluck(:id)).to include(article.id)
  end
end
