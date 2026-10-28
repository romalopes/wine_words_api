class AddGrapesAndRegionsBackToWineProfiles < ActiveRecord::Migration[8.1]
  def up
    add_column :wine_profiles, :grapes, :text, array: true, default: []
    add_column :wine_profiles, :regions, :text, array: true, default: []

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
    remove_column :wine_profiles, :grapes
    remove_column :wine_profiles, :regions
  end
end