# Singleton-style global configuration storage: one row per setting key.
# Values are stored as strings; AppSetting coerces them to their typed values
# (currently a single boolean, more attributes can be added over time).
class CreateAppSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
