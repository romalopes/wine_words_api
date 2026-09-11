require "rails_helper"

RSpec.describe Image, type: :model do
  let(:article) do
    user = User.create!(user_name: "spec", email: "spec@example.com", password: "password123")
    Article.create!(title: "Spec Article", user: user, status: "draft")
  end

  describe "validations" do
    it "is valid with an attached image file" do
      image = Image.new(imageable: article)
      image.file.attach(io: StringIO.new("x"), filename: "test.png", content_type: "image/png")
      expect(image).to be_valid
    end

    it "rejects disallowed content types" do
      image = Image.new(imageable: article)
      image.file.attach(io: StringIO.new("x"), filename: "test.txt", content_type: "text/plain")
      expect(image).not_to be_valid
      expect(image.errors[:file]).to include("must be a JPG, PNG, WEBP or GIF image")
    end
  end

  describe "ordering" do
    it "assigns incremental positions on create" do
      first = Image.create!(imageable: article, file: uploaded_png)
      second = Image.create!(imageable: article, file: uploaded_png)
      expect(first.position).to eq(1)
      expect(second.position).to eq(2)
      expect(article.images.ordered.map(&:position)).to eq([1, 2])
    end
  end

  describe "primary image invariant" do
    it "allows exactly one primary per imageable" do
      Image.create!(imageable: article, file: uploaded_png, primary: true)
      second = Image.new(imageable: article, file: uploaded_png, primary: true)
      expect(second).not_to be_valid
      expect(second.errors[:primary]).to include("There can only be one primary image")
    end

    it "make_primary! demotes the previous primary" do
      first = Image.create!(imageable: article, file: uploaded_png, primary: true)
      second = Image.create!(imageable: article, file: uploaded_png)
      second.make_primary!
      expect(second.reload.primary?).to be true
      expect(first.reload.primary?).to be false
    end
  end

  describe ".reorder!" do
    it "repositions images to match the given id order" do
      a = Image.create!(imageable: article, file: uploaded_png)
      b = Image.create!(imageable: article, file: uploaded_png)
      c = Image.create!(imageable: article, file: uploaded_png)
      Image.reorder!(article, [c.id, a.id, b.id])
      expect(article.images.ordered.map(&:id)).to eq([c.id, a.id, b.id])
      expect(c.reload.position).to eq(1)
    end
  end

  private

  def uploaded_png
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("x"), filename: "test.png", content_type: "image/png"
    )
  end
end