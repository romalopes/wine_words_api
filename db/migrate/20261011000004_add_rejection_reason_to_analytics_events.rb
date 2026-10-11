class AddRejectionReasonToAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :analytics_events, :rejection_reason, :string, limit: 32

    # Index for exclusion reason aggregation
    add_index :analytics_events,
              [:accepted, :rejection_reason],
              name: "idx_analytics_events_rejection_reason",
              where: "accepted = false"
  end
end