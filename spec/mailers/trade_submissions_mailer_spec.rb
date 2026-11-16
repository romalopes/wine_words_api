require "rails_helper"

# Specs for the editorial-team alert sent when a public trade submission is
# created. The mailer only formats what Trade::Submissions::NotifyStaff decided.
RSpec.describe TradeSubmissionsMailer, type: :mailer do
  let(:recipient) do
    User.create!(first_name: "Trade", last_name: "Editor",
                 email: "trade-mail-editor@example.com", password: "password123")
  end
  let(:package) do
    pkg = WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: {
        "company_name" => "Bodega Ejemplo",
        "contact_name" => "Maria Ruiz",
        "email" => "maria@bodega-ejemplo.es",
        "country" => "Spain",
        "role" => "winery"
      }
    )
    pkg.items.create!(proposed_wine_name: "Tinto Reserva", quantity: 1, item_status: "pending")
    pkg
  end

  it "addresses one staff member and names the submission" do
    mail = described_class.new_submission(package.id, recipient.id)

    expect(mail.to).to eq([ recipient.email ])
    expect(mail.subject).to eq("New trade submission ##{package.id} — Bodega Ejemplo")
    expect(mail.body.encoded).to include("Bodega Ejemplo")
    expect(mail.body.encoded).to include("maria@bodega-ejemplo.es")
    expect(mail.body.encoded).to include("Tinto Reserva")
    expect(mail.body.encoded).to include("/admin/trade/packages/#{package.id}")
  end

  it "never puts another recipient in the message" do
    mail = described_class.new_submission(package.id, recipient.id)

    expect(mail.to).to eq([ recipient.email ])
    expect(mail.cc).to be_blank
    expect(mail.bcc).to be_blank
  end
end
