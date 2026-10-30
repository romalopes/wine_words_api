require "rails_helper"
require Rails.root.join("db/migrate/20261028120000_add_grapes_and_regions_back_to_wine_profiles")

RSpec.describe AddGrapesAndRegionsBackToWineProfiles do
  it "converts existing scalar columns to text arrays instead of adding duplicates" do
    connection = ActiveRecord::Base.connection
    connection.remove_column :wine_profiles, :grapes
    connection.remove_column :wine_profiles, :regions
    connection.add_column :wine_profiles, :grapes, :text
    connection.add_column :wine_profiles, :regions, :text

    migration = described_class.new
    migration.suppress_messages { migration.up }

    columns = connection.columns(:wine_profiles).index_by(&:name)

    expect(columns.fetch("grapes")).to be_array
    expect(columns.fetch("grapes").default).to eq("{}")
    expect(columns.fetch("regions")).to be_array
    expect(columns.fetch("regions").default).to eq("{}")
  ensure
    WineProfile.reset_column_information
  end
end
