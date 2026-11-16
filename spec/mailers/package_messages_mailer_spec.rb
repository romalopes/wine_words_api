require "rails_helper"

# The mailer serves both directions of the conversation: submitter -> staff and
# staff -> submitter (or the contact address of a guest submission).
RSpec.describe PackageMessagesMailer, type: :mailer do
  let(:editor_role) { Role.find_or_create_by!(name: "Editor") }

  let(:editor) do
    User.create!(first_name: "Ed", last_name: "Itor",
                 email: "editor@example.com", password: "password123").tap do |user|
      user.roles << editor_role
    end
  end

  let(:submitter) do
    User.create!(first_name: "Maria", last_name: "Ruiz",
                 email: "maria@bodega-ejemplo.es", password: "password123")
  end

  let(:package) do
    WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: {
        "company_name" => "Bodega Ejemplo",
        "contact_name" => "Maria Ruiz",
        "email" => "maria@bodega-ejemplo.es",
        "country" => "Spain",
        "role" => "winery"
      },
      created_by: submitter,
      submitter: submitter
    )
  end

  let(:submitter_message) do
    package.wine_package_messages.create!(
      sender: submitter, sender_type: "submitter",
      body: "Hi, any update on my review request?"
    )
  end

  let(:editor_message) do
    package.wine_package_messages.create!(
      sender: editor, sender_type: "editor",
      body: "Thanks — we are reviewing your Rioja this week."
    )
  end

  it "sends staff a copy that links to the staff page" do
    mail = described_class.new_message(package, editor, submitter_message)

    expect(mail.to).to eq([editor.email])
    expect(mail.subject).to eq("New message on trade submission ##{package.id}")
    expect(mail.body.encoded).to include("Bodega Ejemplo")
    expect(mail.body.encoded).to include("Hi, any update on my review request?")
    expect(mail.body.encoded).to include("/admin/trade/packages/#{package.id}")
  end

  it "sends the submitter a copy that links to their own package" do
    mail = described_class.new_message(package, submitter, editor_message)

    expect(mail.to).to eq([submitter.email])
    expect(mail.body.encoded).to include("we are reviewing your Rioja this week")
    expect(mail.body.encoded).to include("/trade/my-packages/#{package.id}")
    expect(mail.body.encoded).not_to include("/admin/trade/packages")
  end

  it "emails the contact address when the submission has no account" do
    package.update!(created_by: nil, submitter: nil)
    mail = described_class.new_message_to_contact(package, editor_message)

    expect(mail.to).to eq(["maria@bodega-ejemplo.es"])
    expect(mail.body.encoded).to include("we are reviewing your Rioja this week")
    expect(mail.body.encoded).to include("Hello Maria Ruiz")
  end
end
