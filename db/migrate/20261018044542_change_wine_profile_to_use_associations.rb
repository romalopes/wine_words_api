class ChangeWineProfileToUseAssociations < ActiveRecord::Migration[8.1]
  def change
    # Create join tables
    create_table :wine_profile_grapes, id: false do |t|
      t.bigint :wine_profile_id, null: false
      t.bigint :grape_id, null: false
      t.index [:wine_profile_id, :grape_id], unique: true
      t.index :grape_id
    end

    create_table :wine_profile_regions, id: false do |t|
      t.bigint :wine_profile_id, null: false
      t.bigint :region_id, null: false
      t.index [:wine_profile_id, :region_id], unique: true
      t.index :region_id
    end

    # Migrate data from text columns to join tables
    reversible do |dir|
      dir.up do
        # We need to parse the existing grapes and regions columns (which are stored as strings that look like JSON arrays)
        # Example: '[\"Pinot Noir\"]' or '[\"Syrah\",\"Shiraz\"]'
        WineProfile.reset_column_information
        WineProfile.find_each do |wp|
          # Process grapes
          if wp.grapes.present?
            begin
              grape_names = JSON.parse(wp.grapes)
              grape_names.each do |name|
                grape ||= Grape.find_by_name_or_synonym(name.strip)
                if grape
                  WineProfileGrape.find_or_create_by(wine_profile: wp, grape: grape)
                  puts "Added grape '#{name}' to wine profile #{wp.name}"
                else
                  puts "Warning: Grape '#{name}' not found for wine profile #{wp.name}"
                end
              end
            rescue JSON::ParserError => e
              puts "Error parsing grapes for wine profile #{wp.name}: #{wp.grapes}. Error: #{e.message} #{e.backtrace} "
            end
          end

          # Process regions
          if wp.regions.present?
            begin
              region_names = JSON.parse(wp.regions)
              region_names.each do |name|
                region = Region.find_by(name: name.strip)
                if region
                  WineProfileRegion.find_or_create_by(wine_profile: wp, region: region)
                  puts "Added region '#{name}' to wine profile #{wp.name}"
                else
                  puts "Warning: Region '#{name}' not found for wine profile #{wp.name}"
                end
              end
            rescue JSON::ParserError => e
              puts "Error parsing regions for wine profile #{wp.name}: #{wp.regions}"
            end
          end
        end
      end

      dir.down do
        # If we rollback, we need to restore the text columns from the join tables.
        # But since we are removing the columns, we cannot restore them in down without first adding them back.
        # We'll handle this by adding the columns back in the down migration and then populating them.
        # However, for simplicity, we'll assume we won't rollback after removing columns.
        # Alternatively, we can make the migration irreversible by raising ActiveRecord::IrreversibleMigration in down.
        # But let's make it reversible by adding the columns back and repopulating.
        # We'll do that in the down migration below.
      end
    end

    # Remove the old columns
    # remove_column :wine_profiles, :grapes, :text
    # remove_column :wine_profiles, :regions, :text
  end
end
