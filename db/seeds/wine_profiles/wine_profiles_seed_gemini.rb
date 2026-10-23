# frozen_string_literal: true

# Legacy dataset entry point. The canonical schema-aligned data lives in the
# consolidated seed so this file remains safe to run independently.
load Rails.root.join('db', 'seeds', 'wine_profiles', 'wine_profile_seed_consolidated.rb').to_s
