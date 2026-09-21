require "rails_helper"

# Specs for the deadline reminder email. The mailer only formats what the
# Notification (created by the scheduler) already decided.
RSpec.describe WinePackagesMailer, type: :mailer do
  let(:recipient) do
    User.create!(user_name: "Mail Recipient", email: "mail-recipient@example.com",
                 password: "password123")
  end
  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:package) do
    WinePackage.create!(producer: producer, reviewer: recipient, created_by: recipient,
                        source: "unexpected", status: "arrived",
                        arrived_at: 1.month.ago, review_deadline: Date.current + 5)
  end

  def notify(scheduled_date, message: "The review deadline is approaching.")
    Notification.notify!(recipient: recipient, type: "wine_package_deadline",
                         notifiable: package, wine_package: package,
                         scheduled_date: scheduled_date, message: message)
  end

  it "addresses the notification's recipient and names the producer" do
    mail = described_class.review_deadline_notification(notify(package.review_deadline - 5))

    expect(mail.to).to eq([ recipient.email ])
    expect(mail.subject).to eq("Penfolds: wine package review deadline in 5 days")
    expect(mail.body.encoded).to include("Penfolds")
    expect(mail.body.encoded).to include(package.review_deadline.iso8601)
    expect(mail.body.encoded).to include("5 days")
    expect(mail.body.encoded).to include("The review deadline is approaching.")
  end

  it "says the deadline is today for the 0-day reminder" do
    mail = described_class.review_deadline_notification(notify(package.review_deadline))

    expect(mail.subject).to include("is today")
    expect(mail.body.encoded).to include("today")
  end

  it "lists the wines still waiting on a review" do
    package.wine_package_items.create!(quantity: 2, review_requested: true)
    package.wine_package_items.create!(quantity: 1, review_requested: false)

    mail = described_class.review_deadline_notification(notify(package.review_deadline - 15))

    expect(mail.body.encoded).to include("Still waiting on")
    expect(mail.body.encoded).to include("Unmatched wine")
    expect(mail.body.encoded).to include("x2")
  end

  it "links to the React package page using FRONTEND_URL" do
    previous = ENV["FRONTEND_URL"]
    ENV["FRONTEND_URL"] = "https://app.winewords.test"

    mail = described_class.review_deadline_notification(notify(package.review_deadline - 15))

    expect(mail.body.encoded).to include("https://app.winewords.test/wine-packages/#{package.id}")
  ensure
    ENV["FRONTEND_URL"] = previous
  end

  it "renders both a text and an HTML part and sends from the application address" do
    mail = described_class.review_deadline_notification(notify(package.review_deadline - 15))

    expect(mail.text_part).to be_present
    expect(mail.html_part).to be_present
    expect(mail.from).to eq([ "romalopes@gmail.com" ])
  end

  describe "email test mode (use_test_email)" do
    around do |example|
      old = { "use_test_email" => AppSetting.use_test_email?,
              "test_email" => AppSetting.test_email }
      example.run
      AppSetting.set!(:use_test_email, old["use_test_email"]) if old["use_test_email"] != AppSetting.use_test_email?
      AppSetting.set!(:test_email, old["test_email"]) if old["test_email"] != AppSetting.test_email
      AppSetting.where(key: %w[use_test_email test_email]).destroy_all
    end

    it "redirects every email to the configured test address with a [TEST] subject" do
      AppSetting.set!(:use_test_email, true)
      AppSetting.set!(:test_email, "romalopes@yahoo.com.br")

      mail = described_class.review_deadline_notification(notify(package.review_deadline - 5))

      expect(mail.to).to eq([ "romalopes@yahoo.com.br" ])
      expect(mail.subject).to eq("[TEST] Penfolds: wine package review deadline in 5 days")
    end

    it "uses the runtime-configurable test address" do
      AppSetting.set!(:use_test_email, true)
      AppSetting.set!(:test_email, "other-tester@example.com")

      mail = described_class.review_deadline_notification(notify(package.review_deadline - 5))

      expect(mail.to).to eq([ "other-tester@example.com" ])
    end

    it "delivers normally when use_test_email is off" do
      AppSetting.set!(:use_test_email, false)
      AppSetting.set!(:test_email, "romalopes@yahoo.com.br")

      mail = described_class.review_deadline_notification(notify(package.review_deadline - 5))

      expect(mail.to).to eq([ recipient.email ])
      expect(mail.subject).not_to start_with("[TEST]")
    end
  end
end
