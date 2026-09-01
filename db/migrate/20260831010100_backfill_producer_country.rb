# Backfills every existing producer with Australia as its country and then
# enforces that a producer always belongs to a country (null: false).
class BackfillProducerCountry < ActiveRecord::Migration[7.1]
  def up
    australia = Country.find_by(code: "AU") ||
                Country.find_by(name: "Australia") ||
                Country.create!(name: "Australia", code: "AU",
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
