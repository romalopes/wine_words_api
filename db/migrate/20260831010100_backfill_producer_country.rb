# Backfills every existing producer with Australia as its country and then
# enforces that a producer always belongs to a country (null: false).
class BackfillProducerCountry < ActiveRecord::Migration[7.1]
  # Migration-scoped model: the real Country model has a generate_slug
  # callback that references the slug column, which is only added by a LATER
  # migration (20260904000001_add_slug_to_countries). Loading it here would
  # raise "undefined local variable or method 'slug'".
  class MigrationCountry < ActiveRecord::Base
    self.table_name = "countries"
  end

  def up
    australia = MigrationCountry.find_by(code: "AU") ||
                MigrationCountry.find_by(name: "Australia") ||
                MigrationCountry.create!(name: "Australia", code: "AU",
                                         continent: "Oceania", flag_emoji: "\u{1F1E6}\u{1F1FA}")

    say "Backfilling producers with country #{australia.name} (#{australia.id})"
    Producer.where(country_id: nil).find_each do |producer|
      producer.update_column(:country_id, australia.id)
    end

    if Producer.where(country_id: nil).exists?
      raise "Unassigned producer countries remain after backfill"
    end

    change_column_null :producers, :country_id, false
  end

  def down
    change_column_null :producers, :country_id, true
  end
end
