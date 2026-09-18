require "rails_helper"

# Unit specs for WinePackages::MarkArrived — arrival starts the review clock and
# schedules the deadline reminders.
RSpec.describe WinePackages::MarkArrived do
  let(:producer) { Producer.create!(name: "Phase F Arrival Producer") }
  let(:reviewer) { create_user("Phase F Arrival Reviewer", "phase-f-arrival@example.com") }
  let(:arrival_time) { Time.zone.local(2026, 12, 15, 9, 30) }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer, reviewer: reviewer, created_by: reviewer,
        source: "unexpected"
      }.merge(attrs)
    )
  end

  describe ".call" do
    it "moves the package to arrived and starts the review clock" do
      package = create_package

      described_class.call(package, at: arrival_time)

      package.reload
      expect(package.status).to eq("arrived")
      expect(package.arrived_at.to_date).to eq(Date.new(2026, 12, 15))
      expect(package.review_deadline).to eq(Date.new(2027, 1, 15))
    end

    it "returns the package" do
      package = create_package

      expect(described_class.call(package, at: arrival_time)).to eq(package)
    end

    it "keeps a deadline supplied at the same time" do
      package = create_package

      described_class.call(package, at: arrival_time, deadline: Date.new(2027, 2, 1))

      expect(package.reload.review_deadline).to eq(Date.new(2027, 2, 1))
    end

    it "keeps an arrival time supplied up front" do
      package = create_package(arrived_at: arrival_time - 3.days)

      described_class.call(package, at: arrival_time)

      expect(package.reload.arrived_at.to_date).to eq(Date.new(2026, 12, 12))
      expect(package.review_deadline).to eq(Date.new(2027, 1, 12))
    end

    it "schedules the 15/5/0-day reminders for the responsible reviewer" do
      package = create_package

      described_class.call(package, at: arrival_time)

      reminders = Notification.where(wine_package: package).order(:scheduled_date)
      expect(reminders.pluck(:scheduled_date)).to eq(
        [ Date.new(2026, 12, 31), Date.new(2027, 1, 10), Date.new(2027, 1, 15) ]
      )
      expect(reminders.map(&:recipient).uniq).to eq([ reviewer ])
      expect(reminders.map(&:sent_at).uniq).to eq([ nil ])
    end

    it "is idempotent: arriving twice neither moves the clock nor duplicates reminders" do
      package = create_package

      described_class.call(package, at: arrival_time)
      described_class.call(package, at: arrival_time + 5.days)

      package.reload
      expect(package.arrived_at.to_date).to eq(Date.new(2026, 12, 15))
      expect(package.review_deadline).to eq(Date.new(2027, 1, 15))
      expect(Notification.where(wine_package: package).count).to eq(3)
    end

    it "arrives a package that was only announced" do
      package = create_package(status: "announced", announced_at: 2.days.ago)

      described_class.call(package, at: arrival_time)

      expect(package.reload.status).to eq("arrived")
    end

    it "refuses a package that has already been completed" do
      package = create_package(status: "completed", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))

      expect { described_class.call(package, at: arrival_time) }
        .to raise_error(WinePackage::InvalidTransition)
    end
  end
end
