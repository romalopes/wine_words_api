require "rails_helper"
require "tempfile"

RSpec.describe "Api::V1::Images", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    u = User.create!(user_name: "roma", email: "roma@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: "Admin")
    u
  end
  let(:article) { Article.create!(title: "Spec Article", user: user, status: "draft") }

  before { sign_in user }

  describe "POST /api/v1/images" do
    it "attaches uploaded images and returns the rich contract" do
      post "/api/v1/images",
           params: { imageable_type: "article", imageable_id: article.id, images: [uploaded_file] },
           headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["images"]).to be_an(Array)
      expect(body["images"].first).to include("id", "url", "filename", "content_type", "position", "primary")
      expect(article.reload.images.count).to eq(1)
    end

    it "rejects unauthenticated requests" do
      sign_out user
      post "/api/v1/images", params: { imageable_type: "article", imageable_id: article.id, images: [] }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/images/:id" do
    it "removes the image" do
      image = Image.create!(imageable: article, primary: true, file: attached_png)
      delete "/api/v1/images/#{image.id}",
             params: { imageable_type: "article", imageable_id: article.id },
             headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:no_content)
      expect(article.reload.images.count).to eq(0)
    end
  end

  describe "PATCH /api/v1/images/reorder" do
    it "reorders the images" do
      a = Image.create!(imageable: article, file: attached_png)
      b = Image.create!(imageable: article, file: attached_png)
      patch "/api/v1/images/reorder",
            params: { imageable_type: "article", imageable_id: article.id, image_ids: [b.id, a.id] },
            headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(article.images.ordered.map(&:id)).to eq([b.id, a.id])
    end
  end

  describe "PATCH /api/v1/images/:id/primary" do
    it "sets the image as primary and demotes others" do
      a = Image.create!(imageable: article, file: attached_png, primary: true)
      b = Image.create!(imageable: article, file: attached_png)
      patch "/api/v1/images/#{b.id}/primary",
            params: { imageable_type: "article", imageable_id: article.id },
            headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(b.reload.primary?).to be true
      expect(a.reload.primary?).to be false
    end
  end

  private

  def uploaded_file
    dir = Rails.root.join("tmp", "test_fixtures")
    FileUtils.mkdir_p(dir)
    path = dir.join("image.png")
    File.write(path, Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"), mode: "wb")
    fixture_file_upload(path, "image/png")
  end

  def attached_png
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x"), filename: "test.png", content_type: "image/png"
    )
  end
end