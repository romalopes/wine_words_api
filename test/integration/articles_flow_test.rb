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

    # Vintages (article -> vintages -> wine) / producers associations
    link_wine = Wine.first || Wine.create!(name: "T wine", region: "Test", color: "red", prompt: "test")
    link_vintage = Vintage.create!(wine: link_wine, year: 2019, prompt: "test")
    article.vintages << link_vintage
    article.producers << (Producer.first || Producer.create!(name: "T producer"))
    assert article.wines.include?(link_wine), "wines should be reachable through vintages"
    get article_path(article.id)
    assert_response :success
    assert_includes @response.body, "<strong>world</strong>"
    assert_includes @response.body, "#{link_wine.name} #{link_vintage.year}"

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

  test "edit page shows images with remove button and purge works" do
    png = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
    article = Article.create!(user: @user, title: "Img Article", status: "draft")
    article.images.attach(io: StringIO.new(png), filename: "a.png", content_type: "image/png")
    image = article.images.first

    sign_in_for_web(@user)
    get edit_article_path(article.id)
    assert_response :success
    assert_includes @response.body, "Remove"

    assert_difference "article.images.count", -1 do
      patch purge_image_article_path(article.id), params: { image_id: image.id }
    end
    assert_redirected_to edit_article_path(article.id)
  end

  test "article edit form has no nested form; multipart update with image works" do
    png = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
    article = Article.create!(user: @user, title: "Update Me", abstract: "abs",
                              body: "<p>Hello <strong>world</strong></p>", status: "draft",
                              category: @category)

    sign_in_for_web(@user)
    get edit_article_path(article.id)
    assert_response :success
    # No <form> nested inside another <form>
    assert_no_nested_forms

    # Multipart PATCH updates the record and attaches the image
    assert_difference "article.images.count", 1 do
      patch article_path(article.id), params: {
        article: {
          title: "Updated Title", abstract: "new abs", body: "<p>New body</p>",
          status: "published", category_id: @category.id,
          tag_names: "ruby, wine", vintage_ids: [], review_ids: [], producer_ids: [],
          images: [fixture_file_upload("a.png", "image/png")]
        }
      }
    end
    assert_redirected_to article_path(article.id)
    article.reload
    assert_equal "Updated Title", article.title
    assert_equal "published", article.status
    assert_equal "new abs", article.abstract
    assert_equal 1, article.images.count
  end

  test "article purge_image works without nested form or CSRF issue" do
    png = Base64.decode64(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
    article = Article.create!(user: @user, title: "Img Purge", status: "draft")
    article.images.attach(io: StringIO.new(png), filename: "a.png", content_type: "image/png")
    image = article.images.first

    sign_in_for_web(@user)
    get edit_article_path(article.id)
    assert_no_nested_forms

    assert_difference "article.images.count", -1 do
      patch purge_image_article_path(article.id), params: { image_id: image.id }
    end
    assert_redirected_to edit_article_path(article.id)
  end

  test "article can link vintages and reviews; wine search returns matches" do
    wine = Wine.create!(name: "Searchable Shiraz", region: "Barossa", color: "red", prompt: "x")
    vintage = Vintage.create!(wine: wine, year: 2018, prompt: "p")
    review = Review.create!(user: @user, vintage: vintage, title: "Linked via form",
                            score: 90, status: "published")

    sign_in_for_web(@user)

    # Search endpoint used by the picker
    get search_wines_path, params: { q: "shiraz" }, headers: { "ACCEPT" => "application/json" }
    assert_response :success
    results = JSON.parse(@response.body)
    assert results.any? { |w| w["slug"] == wine.slug }, "search should find the wine"
    found = results.find { |w| w["slug"] == wine.slug }
    assert found["vintages"].any? { |v| v["id"] == vintage.id }

    # Create article with vintages + linked review in one request
    post articles_path, params: {
      article: {
        title: "Vintage Article", abstract: "abs", body: "<p>Body</p>",
        status: "draft", category_id: @category.id,
        vintage_ids: [vintage.id], review_ids: [review.id], producer_ids: []
      }
    }
    assert_response :redirect
    created = Article.find_by!(title: "Vintage Article")
    assert_equal [vintage.id], created.vintage_ids
    assert_equal [review.id], created.review_ids
    assert created.wines.include?(wine)

    # Show page lists the vintage and the linked review
    get article_path(created.id)
    assert_response :success
    assert_includes @response.body, "#{wine.name} #{vintage.year}"
    assert_includes @response.body, "Linked via form"

    created.destroy
  end

  test "review new/edit forms use the wine-search vintage picker" do
    wine = Wine.create!(name: "Picker Pinot", region: "Burgundy", color: "red", prompt: "x")
    Vintage.create!(wine: wine, year: 2017, prompt: "p")

    sign_in_for_web(@user)
    get new_review_path
    assert_response :success
    assert_includes @response.body, "review-vintage-search"
    assert_includes @response.body, 'label="Picker Pinot"'
    assert_includes @response.body, "Picker Pinot 2017</option>"
    assert_no_nested_forms

    review = Review.create!(user: @user,
                            vintage: Vintage.find_by!(wine: wine, year: 2017),
                            title: "Picker Review", score: 85, status: "draft")
    get edit_review_path(review.id)
    assert_response :success
    assert_includes @response.body, "review-vintage-search"
    assert_includes @response.body, 'selected="selected"'
    assert_includes @response.body, "Picker Pinot 2017</option>"
    assert_no_nested_forms
  end

  private

  def assert_no_nested_forms
    body = @response.body
    # Walk through the HTML and detect whether any <form> is opened before the
    # matching </form> of the enclosing form (i.e. a nested form).
    depth = 0
    body.scan(/<form\b|<\\?\/form\b/).each do |token|
      if token.start_with?("</")
        depth -= 1
      else
        depth += 1
      end
      assert depth <= 1, "nested form detected at depth #{depth}"
    end
    assert depth.zero?, "unbalanced form tags"
  end

  def sign_in_for_web(user)
    post login_path, params: { email: user.email, password: "password123456" }
    follow_redirect!
  end
end