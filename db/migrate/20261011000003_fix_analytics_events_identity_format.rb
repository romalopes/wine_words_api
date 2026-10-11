class FixAnalyticsEventsIdentityFormat < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :analytics_events, name: "ck_analytics_events_identity_format"
    add_check_constraint :analytics_events,
                         "identity ~ '^(account:[0-9]+|visitor:([0-9a-f-]{36}|erased-[0-9a-f-]+))$'",
                         name: "ck_analytics_events_identity_format"
  end

  def down
    remove_check_constraint :analytics_events, name: "ck_analytics_events_identity_format"
    add_check_constraint :analytics_events,
                         "identity ~ '^(account:\\\\d+|visitor:[0-9a-f-]{36})$'",
                         name: "ck_analytics_events_identity_format"
  end
end
