require "test_helper"

class ArticlesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "art-#{Time.now.to_i}@example.com", password: "password123456", name: "Art Tester")
    @category = Category.find_or_create_by!(name: "News") { |c| c.slug = "news" }
  end

  teardown do
    Article.destroy_all
    Review.destroy_all
    User.where("email LIKE 'art-%@example.com'").destroy_all
  end

  test "draft article is hidden from others and shown to author; publish flow works" do
    article = Article.create!(user: @user, title: "My Draft Story", abstract: "abs",
                              body: "<p>Hello <strong>world</strong></p>", status: "draft",
                              category: @category)

    # Anonymous visitor: draft not listed
    get articles_path
    assert_response :success
    assert_not_includes @response.body, "My Draft Story"

    # Author sees own draft
    sign_in_for_web(@user)
    get articles_path
    assert_response :success
    assert_includes @response.body, "My Draft Story"

    # Another author's draft stays hidden
    other = User.create!(email: "art-o-#{Time.now.to_i}@example.com", password: "password123456", name: "Other")
    Article.create!(user: other, title: "Secret Other Draft", status: "draft")
    get articles_path
    assert_not_includes @response.body, "Secret Other Draft"

    # Publish from dashboard/home perspective
    patch article_path(article.id), params: { article: { status: "published", published_at: Time.current } }
    article.reload
    assert_equal "published", article.status

    # Anonymous now sees it on home and index
    delete logout_path
    get root_path
    assert_includes @response.body, "My Draft Story"
    get articles_path
    assert_includes @response.body, "My Draft Story"

    # Article review link rules
    review = Review.create!(user: @user,
                            vintage: Vintage.first || Vintage.create!(wine: Wine.first || Wine.create!(name: "T wine", region: "Test", color: "red", prompt: "test"), year: 2020, prompt: "test"),
                            title: "linked review", score: 88, status: "published")
    link = article.article_reviews.create!(review: review, status: "published")
    assert_equal "published", link.status

    review.update!(status: "draft")
    link.reload
    assert_equal "draft", link.status, "link must demote when the review is unpublished"
    review.update!(status: "published")

    # Wines / producers associations
    article.wines << (Wine.first || Wine.create!(name: "T wine", region: "Test", color: "red"))
    article.producers << (Producer.first || Producer.create!(name: "T producer"))
    get article_path(article.id)
    assert_response :success
    assert_includes @response.body, "<strong>world</strong>"

    # Edit page renders with linked-reviews section
    sign_in_for_web(@user)
    get edit_article_path(article.id)
    assert_response :success
    assert_includes @response.body, "Linked Reviews"

    # Cleanup extras
    link.destroy
    review.destroy
    article.destroy
  end

  private

  def sign_in_for_web(user)
    post login_path, params: { email: user.email, password: "password123456" }
    follow_redirect!
  end
end