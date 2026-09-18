require "rails_helper"

# Specs for the daily reminder job: it tops up the 15/5/0-day notifications and
# delivers the ones that have come due. It must be idempotent and must never
# nag about a package that is already finished.
RSpec.describe WinePackages::SendReviewDeadlineNotificationsJob, type: :job do
  let(:producer) { Producer.create!(name: "Penfolds") }
  let(:reviewer) do
    user = User.create!(user_name: "Job Reviewer", email: "job-reviewer@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  before { ActionMailer::Base.deliveries.clear }

  def build_package(overrides = {})
    WinePackage.create!({
      producer: producer,
      reviewer: reviewer,
      created_by: reviewer,
      source: "unexpected",
      status: "arrived"
    }.merge(overrides))
  end

  describe "#perform" do
    it "schedules the three reminders around the deadline" do
      package = build_package(arrived_at: Time.current, review_deadline: Date.current + 30)

      described_class.perform_now(Date.current)

      expect(Notification.where(wine_package: package).order(:scheduled_date).pluck(:scheduled_date))
        .to eq([ Date.current + 15, Date.current + 25, Date.current + 30 ])
    end

    it "skips packages without a deadline and finished packages" do
      announced = build_package(status: "announced", arrived_at: nil, review_deadline: nil)
      completed = build_package(status: "completed", arrived_at: 1.month.ago,
                                review_deadline: Date.current)
      cancelled = build_package(status: "cancelled", arrived_at: 1.month.ago,
                                review_deadline: Date.current)

      described_class.perform_now(Date.current)

      expect(Notification.where(wine_package: announced).count).to eq(0)
      expect(Notification.where(wine_package: completed).count).to eq(0)
      expect(Notification.where(wine_package: cancelled).count).to eq(0)
    end

    it "delivers a reminder that has come due and marks it sent" do
      package = build_package(arrived_at: 1.month.ago, review_deadline: Date.current)
      package.wine_package_items.create!(quantity: 1, review_requested: true)

      described_class.perform_now(Date.current)

      notification = Notification.find_by!(wine_package: package, scheduled_date: Date.current)
      expect(notification.sent_at).to be_present
      expect(ActionMailer::Base.deliveries.size).to eq(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ reviewer.email ])
      expect(mail.subject).to include("Penfolds")
      expect(mail.subject).to include("today")
      expect(mail.body.encoded).to include("Penfolds")
    end

    it "leaves future reminders undelivered" do
      build_package(arrived_at: Time.current, review_deadline: Date.current + 30)

      described_class.perform_now(Date.current)

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(Notification.where(sent_at: nil).count).to eq(3)
    end

    it "never emails about a package that is no longer active" do
      package = build_package(status: "completed", arrived_at: 1.month.ago,
                              review_deadline: Date.current)
      notification = Notification.notify!(recipient: reviewer, type: "wine_package_deadline",
                                          notifiable: package, wine_package: package,
                                          scheduled_date: Date.current, message: "due")

      described_class.perform_now(Date.current)

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(notification.reload.sent_at).to be_nil
    end

    it "is idempotent: running twice neither duplicates reminders nor re-sends mail" do
      package = build_package(arrived_at: 1.month.ago, review_deadline: Date.current)

      described_class.perform_now(Date.current)
      described_class.perform_now(Date.current)

      expect(Notification.where(wine_package: package).count).to eq(1)
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "accepts an explicit date, so a catch-up run can be replayed" do
      package = build_package(arrived_at: 1.month.ago, review_deadline: Date.current + 10)

      described_class.perform_now(Date.current + 5)

      expect(Notification.where(wine_package: package, scheduled_date: Date.current + 5).count).to eq(1)
    end
  end
end
