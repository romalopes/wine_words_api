# WinePackage multi-image support: the generic /images endpoints with
# imageable_type=wine_package. Covers create (0/1/many), validation rejections,
# add-without-clobber, individual removal, serializer exposure and the
# WinePackage-specific authorization rules (catalogue managers manage every
# package; a Reviewer only their own; others are read-only).
require "rails_helper"
require "tempfile"

RSpec.describe "WinePackage images", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    u = User.create!(user_name: "Pkg Img Admin", email: "pkg-img-admin@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: "Admin")
    u
  end
  let(:producer) { Producer.create!(name: "Pkg Img Producer") }
  let(:reviewer) do
    u = User.create!(user_name: "Pkg Img Reviewer", email: "pkg-img-reviewer@example.com", password: "password123")
    u.roles << Role.find_or_create_by!(name: "Reviewer")
    u
  end
  let(:outsider) do
    User.create!(user_name: "Pkg Img Outsider", email: "pkg-img-outsider@example.com", password: "password123")
  end
  let(:package) do
    WinePackage.create!(producer: producer, reviewer: reviewer, status: "draft")
  end

  def png_upload(name = "package.png")
    dir = Rails.root.join("tmp", "test_fixtures")
    FileUtils.mkdir_p(dir)
    path = dir.join(name)
    File.write(path, Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"), mode: "wb")
    fixture_file_upload(path, "image/png")
  end

  def upload_images(pkg, files, actor: admin)
    sign_in actor
    post "/api/v1/images",
         params: { imageable_type: "wine_package", imageable_id: pkg.id, images: files },
         headers: { "Accept" => "application/json" }
  end

  describe "POST /api/v1/images (imageable_type=wine_package)" do
    it "attaches multiple images" do
      upload_images(package, [png_upload("a.png"), png_upload("b.png")])
      expect(response).to have_http_status(:ok)
      expect(package.reload.images.count).to eq(2)
      body = JSON.parse(response.body)
      expect(body["images"].map { |i| i["filename"] }).to contain_exactly("a.png", "b.png")
    end

    it "rejects an unsupported file type" do
      dir = Rails.root.join("tmp", "test_fixtures")
      FileUtils.mkdir_p(dir)
      path = dir.join("evil.txt")
      File.write(path, "not an image")
      upload_images(package, [fixture_file_upload(path, "text/plain")])
      expect(response).to have_http_status(:unprocessable_entity)
      expect(package.reload.images.count).to eq(0)
    end

    it "adds images without removing existing ones" do
      upload_images(package, [png_upload("first.png")])
      upload_images(package, [png_upload("second.png")])
      expect(package.reload.images.count).to eq(2)
      expect(package.images.ordered.map { |i| i.file.filename.to_s })
        .to eq(["first.png", "second.png"])
    end

    it "allows a reviewer to manage images for their own package" do
      upload_images(package, [png_upload("rev.png")], actor: reviewer)
      expect(response).to have_http_status(:ok)
    end

    it "forbids a user who is neither catalogue manager nor the reviewer" do
      upload_images(package, [png_upload("nope.png")], actor: outsider)
      expect(response).to have_http_status(:forbidden)
      expect(package.reload.images.count).to eq(0)
    end
  end

  describe "DELETE /api/v1/images/:id" do
    it "removes one image, keeping the others and the package intact" do
      upload_images(package, [png_upload("one.png"), png_upload("two.png")])
      first = package.reload.images.ordered.first

      sign_in admin
      delete "/api/v1/images/#{first.id}",
             params: { imageable_type: "wine_package", imageable_id: package.id },
             headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:no_content)
      expect(package.reload.images.ordered.map { |i| i.file.filename.to_s }).to eq(["two.png"])
      expect(WinePackage.exists?(package.id)).to be true
    end

    it "forbids an outsider from deleting" do
      upload_images(package, [png_upload("keep.png")])
      image = package.reload.images.first

      sign_in outsider
      delete "/api/v1/images/#{image.id}",
             params: { imageable_type: "wine_package", imageable_id: package.id },
             headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:forbidden)
      expect(package.reload.images.count).to eq(1)
    end
  end

  describe "serializer exposure" do
    it "returns images: [] for a package without images" do
      sign_in admin
      get "/api/v1/wine_packages/#{package.id}", as: :json
      body = JSON.parse(response.body)
      expect(body["images"]).to eq([])
      expect(body["image_details"]).to eq([])
      expect(body["primary_image"]).to be_nil
    end

    it "exposes all attached images with the rich contract" do
      upload_images(package, [png_upload("x.png"), png_upload("y.png")])
      sign_in admin
      get "/api/v1/wine_packages/#{package.id}", as: :json
      body = JSON.parse(response.body)
      expect(body["images"].length).to eq(2)
      expect(body["image_ids"].length).to eq(2)
      expect(body["image_details"].first).to include("url", "filename", "content_type", "position", "primary")
      expect(body["primary_image"]).to be_present
    end
  end
end
