class AddGrapesAndRegionsBackToWineProfiles < ActiveRecord::Migration[8.1]
  def up
    ensure_text_array_column(:grapes)
    ensure_text_array_column(:regions)

    # Backfill the new array columns from the profile_grapes / profile_regions
    # join tables so the API keeps returning the same canonical names.
    WineProfile.reset_column_information
    WineProfile.includes(:profile_grapes, :profile_regions).find_each do |wine_profile|
      wine_profile.update_columns(
        grapes: wine_profile.profile_grapes.map(&:name),
        regions: wine_profile.profile_regions.map(&:name)
      )
    end
  end

  def down
    remove_column :wine_profiles, :grapes, if_exists: true
    remove_column :wine_profiles, :regions, if_exists: true
  end

  private

  def ensure_text_array_column(column_name)
    unless column_exists?(:wine_profiles, column_name)
      add_column :wine_profiles, column_name, :text, array: true, default: []
      return
    end

    column = connection.columns(:wine_profiles).find { |candidate| candidate.name == column_name.to_s }

    unless column.array
      quoted_column = connection.quote_column_name(column_name)
      execute <<~SQL.squish
        ALTER TABLE wine_profiles
        ALTER COLUMN #{quoted_column} TYPE text[]
        USING ARRAY[]::text[]
      SQL
    end

    change_column_default :wine_profiles, column_name, from: nil, to: []
  end
end
