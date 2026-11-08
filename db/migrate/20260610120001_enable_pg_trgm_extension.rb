class EnablePgTrgmExtension < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    # GIN indexes for trigram similarity on wines (raw SQL for opclass support)
    unless index_exists?(:wines, "name gin_trgm_ops")
      execute "CREATE INDEX index_wines_on_name_trgm ON wines USING gin (name gin_trgm_ops);"
    end
    unless index_exists?(:wines, "region gin_trgm_ops")
      execute "CREATE INDEX index_wines_on_region_trgm ON wines USING gin (region gin_trgm_ops);"
    end

    # GIN indexes for trigram similarity on wine_profiles
    unless index_exists?(:wine_profiles, "name gin_trgm_ops")
      execute "CREATE INDEX index_wine_profiles_on_name_trgm ON wine_profiles USING gin (name gin_trgm_ops);"
    end
    unless index_exists?(:wine_profiles, "grapes gin_trgm_ops")
      execute "CREATE INDEX index_wine_profiles_on_grapes_trgm ON wine_profiles USING gin (grapes gin_trgm_ops);"
    end
    unless index_exists?(:wine_profiles, "regions gin_trgm_ops")
      execute "CREATE INDEX index_wine_profiles_on_regions_trgm ON wine_profiles USING gin (regions gin_trgm_ops);"
    end
  end
end
