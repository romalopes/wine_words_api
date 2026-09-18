require "rails_helper"

# Unit specs for WinePackage — the unit of work behind the reviewing workflow.
#
# The interesting behaviour lives here rather than in the controllers: the
# legal status transitions, the arrival -> review-deadline clock, and the
# definition of "done" (only review_requested lines block completion).
RSpec.describe WinePackage, type: :model do
  let(:producer) { Producer.create!(name: "Phase F Producer") }
  let(:reviewer) { create_user("Phase F Reviewer", "phase-f-reviewer@example.com") }
  let(:other_user) { create_user("Phase F Other", "phase-f-other@example.com") }
  let(:wine) { Wine.create!(name: "Phase F Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }

  # Arrival is a local time on purpose: the deadline is a calendar date derived
  # from the arrival date, so the zone matters.
  let(:arrival_time) { Time.zone.local(2026, 12, 15, 9, 30) }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def build_package(attrs = {})
    WinePackage.new(
      {
        producer: producer,
        reviewer: reviewer,
        created_by: reviewer,
        source: "unexpected"
      }.merge(attrs)
    )
  end

  def create_package(attrs = {})
    build_package(attrs).tap(&:save!)
  end

  describe "defaults" do
    it "starts as a draft recorded manually" do
      package = WinePackage.new(producer: producer)

      expect(package.status).to eq("draft")
      expect(package.source).to eq("manual")
      expect(package.auto_completed).to be false
      expect(package.arrived_at).to be_nil
      expect(package.review_deadline).to be_nil
      expect(package.reviewed_at).to be_nil
    end

    it "keeps an explicit source" do
      expect(create_package(source: "unexpected").reload.source).to eq("unexpected")
    end
  end

  describe "validations" do
    it "requires a producer" do
      package = build_package(producer: nil)

      expect(package).not_to be_valid
      expect(package.errors[:producer]).to be_present
    end

    it "accepts every documented status" do
      described_class::STATUSES.each do |status|
        attrs = { status: status }
        # A rejected package must carry a reason (that is asserted separately).
        attrs[:rejection_reason] = "No capacity" if status == "rejected"

        expect(create_package(attrs).reload.status).to eq(status)
      end
    end

    it "rejects an undocumented status" do
      package = build_package(status: "nonsense")

      expect(package).not_to be_valid
      expect(package.errors[:status]).to be_present
    end

    it "accepts every documented source" do
      described_class::SOURCES.each do |source|
        expect(create_package(source: source).reload.source).to eq(source)
      end
    end

    it "rejects an undocumented source" do
      package = build_package(source: "nonsense")

      expect(package).not_to be_valid
      expect(package.errors[:source]).to be_present
    end

    it "requires a rejection reason once rejected" do
      package = build_package(status: "rejected")

      expect(package).not_to be_valid
      expect(package.errors[:rejection_reason]).to be_present

      package.rejection_reason = "Not this season"
      expect(package).to be_valid
    end

    it "rejects a review deadline earlier than the arrival date" do
      package = build_package(arrived_at: arrival_time, review_deadline: Date.new(2026, 12, 1))

      expect(package).not_to be_valid
      expect(package.errors[:review_deadline]).to be_present
    end

    it "allows a deadline on the arrival date itself" do
      package = build_package(arrived_at: arrival_time, review_deadline: Date.new(2026, 12, 15))

      expect(package).to be_valid
    end

    it "allows a deadline without an arrival date" do
      package = build_package(review_deadline: Date.new(2026, 1, 1))

      expect(package).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a producer and the people involved" do
      package = create_package

      expect(package.producer).to eq(producer)
      expect(package.reviewer).to eq(reviewer)
      expect(package.created_by).to eq(reviewer)
    end

    it "allows an unassigned reviewer and creator" do
      package = create_package(reviewer: nil, created_by: nil)

      expect(package.reviewer).to be_nil
      expect(package.created_by).to be_nil
      expect(package).to be_valid
    end

    it "records who accepted or rejected a producer request" do
      package = create_package(status: "requested", requested_at: Time.current)
      package.reject!(by: other_user, reason: "No capacity")

      expect(package.rejected_by).to eq(other_user)
      expect(package.accepted_by).to be_nil
    end

    it "exposes its items (and the items collection alias)" do
      package = create_package
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1)

      expect(package.items).to contain_exactly(item)
    end

    it "only lists review-requested items through review_requested_items" do
      package = create_package
      requested = package.wine_package_items.create!(vintage: vintage, review_requested: true)
      package.wine_package_items.create!(vintage: vintage, review_requested: false)

      expect(package.review_requested_items).to contain_exactly(requested)
    end

    it "reaches vintages through its items" do
      package = create_package
      package.wine_package_items.create!(vintage: vintage, review_requested: false)

      expect(package.vintages).to contain_exactly(vintage)
    end

    it "has_one shipment tracking and many tracking events" do
      package = create_package
      tracking = package.create_shipment_tracking!(carrier: "Aramex", provider: "manual")
      event = package.shipment_tracking_events.create!(status: "In transit")

      expect(package.shipment_tracking).to eq(tracking)
      expect(package.shipment_tracking_events).to contain_exactly(event)
    end

    it "has many notifications" do
      package = create_package
      notification = Notification.notify!(
        recipient: reviewer, type: "wine_package_deadline",
        notifiable: package, wine_package: package
      )

      expect(package.notifications).to contain_exactly(notification)
    end

    it "is reachable from the user as reviewer and as creator" do
      as_reviewer = create_package(reviewer: reviewer, created_by: other_user)
      as_creator = create_package(reviewer: nil, created_by: reviewer)

      expect(reviewer.wine_packages).to include(as_reviewer)
      expect(reviewer.created_wine_packages).to include(as_creator)
      expect(reviewer.wine_packages).not_to include(as_creator)
    end

    it "accepts nested attributes for its items" do
      package = create_package(
        wine_package_items_attributes: [
          { vintage_id: vintage.id, quantity: 2, review_requested: true }
        ]
      )

      expect(package.wine_package_items.size).to eq(1)
      expect(package.wine_package_items.first.quantity).to eq(2)
    end
  end

  describe "the workflow transition guard" do
    it "documents exactly the statuses that exist" do
      expect(described_class::VALID_TRANSITIONS.keys)
        .to match_array(described_class::STATUSES)
    end

    it "only ever lists real statuses as transition targets" do
      described_class::VALID_TRANSITIONS.each_value do |targets|
        expect(targets).to all(be_in(described_class::STATUSES))
      end
    end

    it "allows exactly the documented moves from every status" do
      described_class::STATUSES.each do |status|
        allowed = described_class::VALID_TRANSITIONS.fetch(status)
        package = build_package(status: status)

        described_class::STATUSES.each do |target|
          expectation = allowed.include?(target)
          expect(package.can_transition_to?(target)).to eq(expectation),
            "#{status} -> #{target} should #{expectation ? '' : 'not '}be allowed"
        end
      end
    end

    it "reports an unknown status as not reachable" do
      expect(build_package.can_transition_to?("bogus")).to be false
    end

    it "reports a move to the current status as not a move" do
      expect(build_package(status: "draft").can_transition_to?("draft")).to be false
    end
  end

  describe "#transition_to!" do
    it "performs a legal transition" do
      package = create_package(status: "announced")

      expect(package.transition_to!("in_transit")).to be true
      expect(package.reload.status).to eq("in_transit")
    end

    it "refuses an illegal transition and leaves the record untouched" do
      package = create_package(status: "draft")

      expect { package.transition_to!("completed") }.to raise_error(
        WinePackage::InvalidTransition, /cannot transition from "draft" to "completed"/
      )
      expect(package.reload.status).to eq("draft")
    end

    it "refuses to move out of a rejected package" do
      package = create_package(status: "rejected", rejection_reason: "No capacity")

      expect { package.transition_to!("accepted") }
        .to raise_error(WinePackage::InvalidTransition)
    end

    it "raises ArgumentError for a status that does not exist" do
      expect { create_package.transition_to!("bogus") }
        .to raise_error(ArgumentError, /unknown status/)
    end

    it "treats a transition to the current status as an idempotent no-op" do
      package = create_package
      package.notes = "Saved alongside the no-op"

      expect(package.transition_to!("draft")).to be true
      expect(package.reload.status).to eq("draft")
      expect(package.notes).to eq("Saved alongside the no-op")
    end
  end

  describe "workflow actions" do
    it "records a producer request" do
      package = create_package
      package.request!(at: arrival_time)

      expect(package.reload.status).to eq("requested")
      expect(package.requested_at).to be_within(1.second).of(arrival_time)
    end

    it "keeps the original requested_at when asked twice" do
      package = create_package
      package.request!(at: arrival_time)
      package.request!(at: arrival_time + 3.days)

      expect(package.reload.requested_at).to be_within(1.second).of(arrival_time)
    end

    it "accepts a request and records the actor" do
      package = create_package(status: "requested")
      package.accept!(by: reviewer, at: arrival_time)

      package.reload
      expect(package.status).to eq("accepted")
      expect(package.accepted_by).to eq(reviewer)
      expect(package.accepted_at).to be_within(1.second).of(arrival_time)
    end

    it "clears earlier rejection state when accepting" do
      package = create_package(status: "requested")
      package.update_columns(rejected_at: 1.day.ago, rejected_by_id: other_user.id,
                             rejection_reason: "Changed their mind")

      package.accept!(by: reviewer)

      package.reload
      expect(package.rejected_at).to be_nil
      expect(package.rejected_by_id).to be_nil
      expect(package.rejection_reason).to be_nil
    end

    it "rejects a request with a reason and the actor" do
      package = create_package(status: "requested")
      package.reject!(by: reviewer, reason: "Not this season", at: arrival_time)

      package.reload
      expect(package.status).to eq("rejected")
      expect(package.rejection_reason).to eq("Not this season")
      expect(package.rejected_by).to eq(reviewer)
      expect(package.rejected_at).to be_within(1.second).of(arrival_time)
    end

    it "refuses to reject without a reason" do
      package = create_package(status: "requested")

      expect { package.reject!(by: reviewer) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(package.reload.status).to eq("requested")
    end

    it "moves an announced package in transit" do
      package = create_package(status: "announced")
      package.mark_in_transit!

      expect(package.reload.status).to eq("in_transit")
    end

    it "starts reviewing an arrived package" do
      package = create_package(status: "arrived", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))
      package.start_reviewing!

      expect(package.reload.status).to eq("reviewing")
    end

    it "completes and stamps reviewed_at" do
      package = create_package(status: "arrived", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))
      package.mark_completed!(at: arrival_time)

      package.reload
      expect(package.status).to eq("completed")
      expect(package.reviewed_at).to be_within(1.second).of(arrival_time)
    end

    it "completes deliberately even with reviews outstanding" do
      package = create_package(status: "arrived", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))
      package.wine_package_items.create!(vintage: vintage, review_requested: true)

      package.mark_completed!

      expect(package.reload.status).to eq("completed")
      expect(package.pending_review_count).to eq(1)
      expect(package.auto_completed).to be false
    end

    it "reopens a completed package and clears the automatic-completion flag" do
      package = create_package(status: "completed", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15), auto_completed: true)
      package.reopen!

      package.reload
      expect(package.status).to eq("reviewing")
      expect(package.auto_completed).to be false
    end

    it "cancels a package" do
      package = create_package(status: "announced")
      package.cancel!

      expect(package.reload.status).to eq("cancelled")
    end

    it "refuses to cancel an already completed package" do
      package = create_package(status: "completed", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))

      expect { package.cancel! }.to raise_error(WinePackage::InvalidTransition)
    end

    it "refuses to complete a draft package" do
      expect { create_package.mark_completed! }
        .to raise_error(WinePackage::InvalidTransition)
    end
  end

  describe "arrival and the review clock" do
    it "defaults the deadline to one calendar month after arrival" do
      package = create_package
      package.mark_arrived!(at: arrival_time)

      package.reload
      expect(package.status).to eq("arrived")
      expect(package.arrived_at.to_date).to eq(Date.new(2026, 12, 15))
      expect(package.review_deadline).to eq(Date.new(2027, 1, 15))
    end

    it "clamps the deadline to the end of a shorter month" do
      package = create_package
      package.mark_arrived!(at: Time.zone.local(2026, 1, 31, 12, 0))

      expect(package.reload.review_deadline).to eq(Date.new(2026, 2, 28))
    end

    it "preserves a deadline supplied up front" do
      package = create_package(review_deadline: Date.new(2027, 3, 1))
      package.mark_arrived!(at: arrival_time)

      expect(package.reload.review_deadline).to eq(Date.new(2027, 3, 1))
    end

    it "preserves an arrival time supplied up front and derives the deadline from it" do
      package = create_package(arrived_at: arrival_time - 5.days)
      package.mark_arrived!(at: arrival_time)

      expect(package.reload.arrived_at.to_date).to eq(Date.new(2026, 12, 10))
      expect(package.review_deadline).to eq(Date.new(2027, 1, 10))
    end

    it "computes the default deadline, or nothing before arrival" do
      package = create_package

      expect(package.default_review_deadline).to be_nil

      package.mark_arrived!(at: arrival_time)
      expect(package.default_review_deadline).to eq(Date.new(2027, 1, 15))
    end

    it "refuses to arrive from a completed package" do
      package = create_package(status: "completed", arrived_at: arrival_time,
                               review_deadline: Date.new(2027, 1, 15))

      expect { package.mark_arrived!(at: arrival_time) }
        .to raise_error(WinePackage::InvalidTransition)
    end
  end

  # Progress is deliberately tested on an "announced" package: completion is a
  # separate concern (and is covered by the item specs), so these examples stay
  # free of auto-completion side effects.
  describe "review progress" do
    let(:package) { create_package(status: "announced") }

    def add_item(pkg, requested:, review: nil)
      pkg.wine_package_items.create!(vintage: vintage, review_requested: requested, review: review)
    end

    def published_review(title)
      Review.create!(vintage: vintage, user: reviewer, title: title, score: 90,
                     status: "published")
    end

    it "treats a package with nothing requested as nothing left to do" do
      add_item(package, requested: false)

      expect(package.pending_review_count).to eq(0)
      expect(package.reviews_complete?).to be true
      expect(package.review_progress_percent).to eq(100)
      expect(package.review_progress).to eq(requested: 0, reviewed: 0, pending: 0, percent: 100)
    end

    it "never lets a non-review line block completion" do
      add_item(package, requested: false)
      add_item(package, requested: false, review: published_review("Phase F extra"))

      expect(package.pending_review_count).to eq(0)
      expect(package.reviews_complete?).to be true
    end

    it "treats a requested line with no review as pending" do
      item = add_item(package, requested: true)

      expect(package.pending_review_items).to contain_exactly(item)
      expect(package.pending_review_count).to eq(1)
      expect(package.reviews_complete?).to be false
      expect(package.review_progress_percent).to eq(0)
    end

    it "does not count a draft review as reviewed" do
      draft = Review.create!(vintage: vintage, user: reviewer, title: "Phase F draft",
                             score: 90, status: "draft")
      add_item(package, requested: true, review: draft)

      expect(package.pending_review_count).to eq(1)
      expect(package.review_progress_percent).to eq(0)
    end

    it "counts a published review as reviewed" do
      item = add_item(package, requested: true, review: published_review("Phase F published"))

      expect(item.reviewed?).to be true
      expect(package.pending_review_items).to be_empty
      expect(package.reviews_complete?).to be true
      expect(package.review_progress).to eq(requested: 1, reviewed: 1, pending: 0, percent: 100)
    end

    it "reports partial progress across mixed lines" do
      add_item(package, requested: true, review: published_review("Phase F done"))
      add_item(package, requested: true)
      add_item(package, requested: false)

      expect(package.review_progress).to eq(requested: 2, reviewed: 1, pending: 1, percent: 50)
      expect(package.reviewed_items.size).to eq(1)
    end

    it "counts a line as pending again when its review is unpublished" do
      review = published_review("Phase F unpublish")
      add_item(package, requested: true, review: review)
      expect(package.reviews_complete?).to be true

      review.update!(status: "draft")
      package.reload

      expect(package.reviews_complete?).to be false
      expect(package.pending_review_count).to eq(1)
    end
  end

  describe "scopes" do
    it "keeps finished business out of active" do
      active = create_package(status: "arrived", arrived_at: arrival_time,
                              review_deadline: Date.new(2027, 1, 15))
      create_package(status: "completed", arrived_at: arrival_time,
                     review_deadline: Date.new(2027, 1, 15))
      create_package(status: "cancelled")
      create_package(status: "rejected", rejection_reason: "No capacity")

      expect(described_class.active).to contain_exactly(active)
    end

    it "finds overdue packages and ignores finished ones" do
      overdue = create_package(status: "arrived", arrived_at: 60.days.ago,
                               review_deadline: 30.days.ago.to_date)
      fresh = create_package(status: "arrived", arrived_at: Time.current,
                             review_deadline: Date.current + 10)
      completed = create_package(status: "completed", arrived_at: 60.days.ago,
                                 review_deadline: 30.days.ago.to_date)
      rejected = create_package(status: "rejected", rejection_reason: "No capacity",
                                arrived_at: 60.days.ago, review_deadline: 30.days.ago.to_date)

      expect(described_class.overdue).to contain_exactly(overdue)
      expect(described_class.overdue).not_to include(fresh, completed, rejected)
    end

    it "finds packages whose deadline is on or after a date" do
      upcoming = create_package(status: "arrived", arrived_at: Time.current,
                                review_deadline: Date.current + 10)
      older = create_package(status: "arrived", arrived_at: 60.days.ago,
                             review_deadline: 30.days.ago.to_date)

      expect(described_class.with_upcoming_deadline).to contain_exactly(upcoming)
      expect(described_class.with_upcoming_deadline(60.days.ago.to_date))
        .to include(upcoming, older)
    end

    it "ignores packages without a deadline" do
      create_package(status: "announced")

      expect(described_class.with_upcoming_deadline).to be_empty
    end

    it "finds arrived or reviewing packages that still have requested lines" do
      needs_work = create_package(status: "arrived", arrived_at: arrival_time,
                                  review_deadline: Date.new(2027, 1, 15))
      needs_work.wine_package_items.create!(vintage: vintage, review_requested: true)

      no_request = create_package(status: "arrived", arrived_at: arrival_time,
                                  review_deadline: Date.new(2027, 1, 15))
      no_request.wine_package_items.create!(vintage: vintage, review_requested: false)

      not_arrived = create_package(status: "announced")
      not_arrived.wine_package_items.create!(vintage: vintage, review_requested: true)

      expect(described_class.requiring_reviews).to contain_exactly(needs_work)
    end

    it "orders by recency" do
      first = create_package
      second = create_package

      expect(described_class.by_recency.to_a).to eq([ second, first ])
    end
  end

  describe "#overdue? and #days_until_deadline" do
    it "counts down to a future deadline" do
      package = create_package(status: "arrived", arrived_at: Time.current,
                               review_deadline: Date.current + 7)

      expect(package.days_until_deadline).to eq(7)
      expect(package.overdue?).to be false
    end

    it "is overdue once the deadline has passed" do
      package = create_package(status: "arrived", arrived_at: 60.days.ago,
                               review_deadline: 1.day.ago.to_date)

      expect(package.days_until_deadline).to eq(-1)
      expect(package.overdue?).to be true
    end

    it "is never overdue once the package is finished" do
      completed = create_package(status: "completed", arrived_at: 60.days.ago,
                                 review_deadline: 30.days.ago.to_date)
      cancelled = create_package(status: "cancelled", arrived_at: 60.days.ago,
                                 review_deadline: 30.days.ago.to_date)
      rejected = create_package(status: "rejected", rejection_reason: "No capacity",
                                arrived_at: 60.days.ago, review_deadline: 30.days.ago.to_date)

      expect(completed.overdue?).to be false
      expect(cancelled.overdue?).to be false
      expect(rejected.overdue?).to be false
    end

    it "has no countdown without a deadline" do
      package = create_package

      expect(package.days_until_deadline).to be_nil
      expect(package.overdue?).to be false
    end
  end

  describe "dependent records" do
    it "takes its items, tracking, tracking events and notifications with it" do
      package = create_package
      package.wine_package_items.create!(vintage: vintage, review_requested: true)
      package.create_shipment_tracking!(carrier: "Aramex", provider: "manual")
      package.shipment_tracking_events.create!(status: "In transit")
      Notification.notify!(recipient: reviewer, type: "wine_package_deadline",
                           notifiable: package, wine_package: package)

      package.destroy

      expect(WinePackageItem.where(wine_package_id: package.id)).to be_empty
      expect(ShipmentTracking.where(wine_package_id: package.id)).to be_empty
      expect(ShipmentTrackingEvent.where(wine_package_id: package.id)).to be_empty
      expect(Notification.where(wine_package_id: package.id)).to be_empty
    end

    it "leaves the reviews themselves alone" do
      package = create_package
      review = Review.create!(vintage: vintage, user: reviewer, title: "Phase F survivor",
                              score: 90, status: "published")
      package.wine_package_items.create!(vintage: vintage, review: review,
                                         review_requested: true)

      package.destroy

      expect(Review.exists?(review.id)).to be true
      expect(review.reload.wine_package_items).to be_empty
    end

    it "detaches (rather than deletes) the package when its reviewer is deleted" do
      package = create_package(reviewer: other_user, created_by: other_user)

      other_user.destroy

      package.reload
      expect(package).to be_persisted
      expect(package.reviewer_id).to be_nil
      expect(package.created_by_id).to be_nil
    end
  end
end
