require "rails_helper"

# Unit specs for WinePackageAttachment — one typed file on a package or a
# single package line (issue #199 §3).
#
# What matters here: attachment_type/file validations, the shared/internal
# visibility boundary (internal files never leave the editorial surface), and
# the per-item anchor. Bytes live in Active Storage; downloads are signed URLs
# generated per request (covered by the request specs).
RSpec.describe WinePackageAttachment, type: :model do
  let(:producer) { Producer.create!(name: "Attachment Producer") }
  let(:editor)   { create_user("Attachment Editor", "attachment-editor@example.com") }
  let(:wine)     { Wine.create!(name: "Attachment Wine", producer: producer, color: "Red") }
  let(:vintage)  { Vintage.create!(wine: wine, year: 2020) }

  def create_user(name, email)
    User.create!(first_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer, reviewer: editor, created_by: editor,
        source: "producer_request", status: "requested"
      }.merge(attrs)
    )
  end

  def build(package, attrs = {})
    attachment = package.wine_package_attachments.new(
      { uploaded_by: editor, attachment_type: "bottle_photo" }.merge(attrs)
    )
    attachment.file.attach(
      io: StringIO.new("jpg-bytes"), filename: "bottle.jpg", content_type: "image/jpeg"
    )
    attachment
  end

  def attach(package, attrs = {})
    attachment = build(package, attrs)
    attachment.save!
    attachment
  end

  describe "validations" do
    it "requires a file" do
      attachment = create_package.wine_package_attachments.new(
        uploaded_by: editor, attachment_type: "bottle_photo"
      )

      expect(attachment).not_to be_valid
      expect(attachment.errors[:file]).to be_present
    end

    it "requires a known attachment type" do
      attachment = build(create_package, attachment_type: "unknown_kind")

      expect(attachment).not_to be_valid
      expect(attachment.errors[:attachment_type]).to be_present
    end

    it "rejects disallowed content types" do
      attachment = build(create_package)
      attachment.file.attach(
        io: StringIO.new("not-a-real-exe"), filename: "virus.exe",
        content_type: "application/x-msdownload"
      )

      expect(attachment).not_to be_valid
      expect(attachment.errors[:file]).to be_present
    end

    it "accepts every declared attachment type" do
      package = create_package

      WinePackageAttachment::ATTACHMENT_TYPES.each do |type|
        attachment = attach(package, attachment_type: type)
        expect(attachment).to be_persisted
        expect(attachment.attachment_type).to eq(type)
      end
    end
  end

  describe "visibility" do
    it "defaults to shared visibility" do
      attachment = attach(create_package)

      expect(attachment).to be_shared
      expect(attachment.visibility).to eq("shared")
    end

    it "shows shared attachments to every viewer who can see the package" do
      attachment = attach(create_package)

      expect(attachment.wine_package.wine_package_attachments.visible_to(false)).to include(attachment)
    end

    it "hides internal attachments from producer-side viewers" do
      attachment = attach(create_package, visibility: "internal")

      expect(attachment).to be_internal
      expect(attachment.wine_package.wine_package_attachments.visible_to(false)).not_to include(attachment)
    end

    it "shows internal attachments to editorial viewers" do
      attachment = attach(create_package, visibility: "internal")

      expect(attachment.wine_package.wine_package_attachments.visible_to(true)).to include(attachment)
    end
  end

  describe "per-item anchoring" do
    it "can be anchored to a single wine line" do
      package = create_package
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1)
      attachment = attach(package, wine_package_item: item)

      expect(attachment.wine_package_item_id).to eq(item.id)
      expect(item.wine_package_attachments).to include(attachment)
    end
  end

  describe "package scoping" do
    it "is destroyed with its package" do
      package = create_package
      attachment = attach(package)

      expect(package.wine_package_attachments).to include(attachment)

      package.destroy
      expect { attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
