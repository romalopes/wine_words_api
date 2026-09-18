# A WinePackage is the unit of work for the reviewing workflow: a producer
# sends (or announces) one or more wines to Wine Words, and a reviewer is
# responsible for reviewing every wine that was flagged as review_requested.
#
# It is deliberately producer-centric and reviewer-owned. There is no Project
# association: the codebase has no Project model, so a dangling foreign key
# would be worse than the coupling it avoids. If a Project model is introduced
# later, an optional `project_id` column can be added additively.
#
# Status and source are string-backed (the app's convention — see Review#status
# and Producer#producer_type); the allowed values and the legal transitions
# live on the model, not in a state-machine gem.
class CreateWinePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_packages do |t|
      t.references :producer, null: false, foreign_key: true
      # The reviewer responsible for the package. Any signed-in User may be a
      # reviewer; the "Reviewer" role is not required for domain ownership.
      t.references :reviewer, null: true, foreign_key: { to_table: :users }
      # Who recorded the package (for audit; may differ from the reviewer).
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      # "draft" | "requested" | "accepted" | "rejected" | "announced" |
      # "in_transit" | "arrived" | "reviewing" | "completed" | "cancelled"
      t.string :status, null: false, default: "draft", limit: 32
      # "manual" | "unexpected" | "producer_request" | "producer_announcement"
      t.string :source, null: false, default: "manual", limit: 32

      # Lifecycle timestamps.
      t.datetime :announced_at
      t.date :expected_at
      t.datetime :arrived_at
      # One calendar month after arrival by default; populated on arrival
      # unless an explicit deadline was supplied.
      t.date :review_deadline
      t.datetime :reviewed_at

      # Carrier-independent tracking snapshot. The provider-aware aggregate
      # (with its event history) lives in shipment_trackings /
      # shipment_tracking_events; these columns keep the current state cheap to
      # read on the package itself.
      t.string :tracking_carrier, limit: 64
      t.string :tracking_number, limit: 128
      t.string :tracking_url, limit: 500
      t.string :tracking_status, limit: 64
      t.datetime :tracking_status_updated_at
      t.datetime :estimated_delivery_at
      t.datetime :delivered_at

      # Producer-request workflow (accept / reject). Present now so the future
      # Producer Portal is additive rather than a schema redesign; there is no
      # Producer <-> Account coupling yet.
      t.datetime :requested_at
      t.datetime :accepted_at
      t.references :accepted_by, null: true, foreign_key: { to_table: :users }
      t.datetime :rejected_at
      t.references :rejected_by, null: true, foreign_key: { to_table: :users }
      t.text :rejection_reason

      t.text :notes

      t.timestamps
    end

    add_index :wine_packages, :status
    add_index :wine_packages, :review_deadline
    add_index :wine_packages, :tracking_number
  end
end
