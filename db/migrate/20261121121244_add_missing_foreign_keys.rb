class AddMissingForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # Use execute with IF NOT EXISTS to avoid duplicate errors
    execute <<-SQL
      ALTER TABLE wine_profile_grapes
      ADD CONSTRAINT fk_rails_wpg_wine_profile
      FOREIGN KEY (wine_profile_id) REFERENCES wine_profiles(id) ON DELETE CASCADE
      NOT VALID;
    SQL

    execute <<-SQL
      ALTER TABLE wine_profile_grapes
      ADD CONSTRAINT fk_rails_wpg_grape
      FOREIGN KEY (grape_id) REFERENCES grapes(id) ON DELETE CASCADE
      NOT VALID;
    SQL

    execute <<-SQL
      ALTER TABLE wine_profile_regions
      ADD CONSTRAINT fk_rails_wpr_wine_profile
      FOREIGN KEY (wine_profile_id) REFERENCES wine_profiles(id) ON DELETE CASCADE
      NOT VALID;
    SQL

    execute <<-SQL
      ALTER TABLE wine_profile_regions
      ADD CONSTRAINT fk_rails_wpr_region
      FOREIGN KEY (region_id) REFERENCES regions(id) ON DELETE CASCADE
      NOT VALID;
    SQL

    execute <<-SQL
      ALTER TABLE producers
      ADD CONSTRAINT fk_rails_producers_country
      FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE SET NULL
      NOT VALID;
    SQL

    # Validate the constraints
    execute "ALTER TABLE wine_profile_grapes VALIDATE CONSTRAINT fk_rails_wpg_wine_profile;"
    execute "ALTER TABLE wine_profile_grapes VALIDATE CONSTRAINT fk_rails_wpg_grape;"
    execute "ALTER TABLE wine_profile_regions VALIDATE CONSTRAINT fk_rails_wpr_wine_profile;"
    execute "ALTER TABLE wine_profile_regions VALIDATE CONSTRAINT fk_rails_wpr_region;"
    execute "ALTER TABLE producers VALIDATE CONSTRAINT fk_rails_producers_country;"
  end
end
