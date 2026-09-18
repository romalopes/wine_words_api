require "rails_helper"

# Unit specs for Notification — one event per reminder, shared by email delivery
# and the in-app list.
#
# The important contract is idempotency: a package may only have one reminder of
# a given type per day, no matter how often the scheduler runs, and the
# database's unique index is the concurrency guard behind that.
RSpec.describe Notification, type: :model do
  let(:producer) { Producer.create!(name: "Phase F Notification Producer") }
  let(:recipient) { create_user("Phase F Notified", "phase-f-notified@example.com") }
  let(:other_recipient) { create_user("Phase F Other Notified", "phase-f-other-notified@example.com") }
  let(:package) { create_package }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package
    WinePackage.create!(producer: producer, reviewer: recipient, created_by: recipient,
                        source: "unexpected", status: "arrived",
                        arrived_at: Time.current, review_deadline: Date.current + 30)
  end

  def notify(attrs = {})
    described_class.notify!(
      **{
        recipient: recipient,
        type: "wine_package_deadline",
        notifiable: package,
        wine_package: package,
        message: "Deadline approaching"
      }.merge(attrs)
    )
  end

  describe "the type vocabulary" do
    it "documents the types the application knows about" do
      expect(described_class::TYPES).to include(
        "wine_package_deadline", "wine_package_arrived",
        "wine_package_completed", "wine_package_rejected"
      )
    end
  end

  describe "validations and defaults" do
    it "requires a recipient" do
      notification = described_class.new(notification_type: "wine_package_deadline")

      expect(notification).not_to be_valid
      expect(notification.errors[:recipient]).to be_present
    end

    it "requires a known notification type" do
      notification = described_class.new(recipient: recipient, notification_type: "bogus")

      expect(notification).not_to be_valid
      expect(notification.errors[:notification_type]).to be_present
    end

    it "defaults the scheduled date to today" do
      notification = described_class.new(recipient: recipient,
                                         notification_type: "wine_package_deadline")
      # The default is applied by a before_validation callback.
      notification.valid?

      expect(notification.scheduled_date).to eq(Date.current)
    end

    it "keeps an explicitly scheduled date" do
      notification = described_class.new(recipient: recipient,
                                         notification_type: "wine_package_deadline",
                                         scheduled_date: Date.current + 5)

      expect(notification.scheduled_date).to eq(Date.current + 5)
    end

    it "allows a generic notification with no package or notifiable" do
      notification = described_class.new(recipient: recipient,
                                         notification_type: "wine_package_arrived")

      expect(notification).to be_valid
      expect(notification.wine_package).to be_nil
      expect(notification.notifiable).to be_nil
    end

    it "starts undelivered and unread" do
      notification = notify

      expect(notification.sent?).to be false
      expect(notification.read?).to be false
      expect(notification.sent_at).to be_nil
      expect(notification.read_at).to be_nil
    end
  end

  describe ".notify!" do
    it "creates the reminder with its message and subject" do
      notification = notify

      expect(notification).to be_persisted
      expect(notification.recipient).to eq(recipient)
      expect(notification.wine_package).to eq(package)
      expect(notification.notifiable).to eq(package)
      expect(notification.notification_type).to eq("wine_package_deadline")
      expect(notification.message).to eq("Deadline approaching")
      expect(notification.scheduled_date).to eq(Date.current)
    end

    it "accepts the type as a symbol" do
      notification = notify(type: :wine_package_deadline)

      expect(notification.notification_type).to eq("wine_package_deadline")
    end

    it "returns the existing reminder for the same package, type and day" do
      first = notify
      second = notify(message: "Ignored")

      expect(second.id).to eq(first.id)
      expect(described_class.where(wine_package: package).count).to eq(1)
      expect(second.reload.message).to eq("Deadline approaching")
    end

    it "keeps the first recipient when somebody else asks for the same reminder" do
      first = notify(recipient: recipient)
      second = notify(recipient: other_recipient)

      expect(second.id).to eq(first.id)
      expect(second.reload.recipient).to eq(recipient)
    end

    it "creates a separate reminder per day" do
      first = notify
      second = notify(scheduled_date: Date.current + 1)

      expect(second.id).not_to eq(first.id)
      expect(described_class.where(wine_package: package).count).to eq(2)
    end

    it "creates a separate reminder per type" do
      first = notify
      second = notify(type: "wine_package_arrived")

      expect(second.id).not_to eq(first.id)
      expect(described_class.where(wine_package: package).count).to eq(2)
    end

    it "creates a separate reminder per package" do
      other_package = WinePackage.create!(producer: producer, reviewer: recipient,
                                          created_by: recipient, source: "unexpected",
                                          status: "arrived", arrived_at: Time.current,
                                          review_deadline: Date.current + 30)
      first = notify
      second = notify(wine_package: other_package, notifiable: other_package)

      expect(second.id).not_to eq(first.id)
    end

    it "reuses a package-less reminder for the same type and day" do
      first = described_class.notify!(recipient: recipient, type: "wine_package_arrived")
      second = described_class.notify!(recipient: other_recipient, type: "wine_package_arrived")

      expect(second.id).to eq(first.id)
    end
  end

  describe "#mark_read! and #mark_sent!" do
    it "stamps read_at once" do
      notification = notify
      first_read = Time.zone.local(2026, 3, 1, 9, 0)

      notification.mark_read!(at: first_read)
      expect(notification.read?).to be true

      notification.mark_read!(at: first_read + 2.days)
      expect(notification.reload.read_at).to be_within(1.second).of(first_read)
    end

    it "stamps sent_at once" do
      notification = notify
      first_sent = Time.zone.local(2026, 3, 1, 7, 0)

      notification.mark_sent!(at: first_sent)
      expect(notification.sent?).to be true

      notification.mark_sent!(at: first_sent + 1.day)
      expect(notification.reload.sent_at).to be_within(1.second).of(first_sent)
    end
  end

  describe "scopes" do
    it "separates unread from read" do
      unread = notify(scheduled_date: Date.current)
      read = notify(scheduled_date: Date.current + 1)
      read.mark_read!

      expect(described_class.unread).to contain_exactly(unread)
      expect(described_class.read).to contain_exactly(read)
    end

    it "separates delivered from undelivered" do
      undelivered = notify(scheduled_date: Date.current)
      delivered = notify(scheduled_date: Date.current + 1)
      delivered.mark_sent!

      expect(described_class.undelivered).to contain_exactly(undelivered)
      expect(described_class.delivered).to contain_exactly(delivered)
    end

    it "filters by scheduled date" do
      today = notify(scheduled_date: Date.current)
      notify(scheduled_date: Date.current + 4)

      expect(described_class.for_date(Date.current)).to contain_exactly(today)
    end

    it "orders by recency" do
      first = notify(scheduled_date: Date.current)
      second = notify(scheduled_date: Date.current + 1)

      expect(described_class.by_recency.to_a).to eq([ second, first ])
    end
  end

  describe "package and recipient associations" do
    it "is destroyed with its package" do
      notification = notify

      package.destroy

      expect(described_class.exists?(notification.id)).to be false
    end

    it "is reachable from the recipient" do
      notification = notify

      expect(recipient.notifications).to include(notification)
    end
  end
end
