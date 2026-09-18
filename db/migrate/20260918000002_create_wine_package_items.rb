# A WinePackageItem is one line in a package: a wine (resolved to a specific
# Vintage whenever possible) plus whether a review was requested for it.
#
# Deliberately:
#   * `vintage_id` is optional — an unexpected package may arrive with a wine
#     that does not exist in the catalogue yet;
#   * there is NO unique index on (wine_package_id, vintage_id) — the same
#     vintage may legitimately appear in many packages over time;
#   * review_requested is the ONLY signal that blocks package completion. A
#     non-review wine never prevents the package from being completed.
class CreateWinePackageItems < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_package_items do |t|
      t.references :wine_package, null: false, foreign_key: true
      t.references :vintage, null: true, foreign_key: true

      t.integer :quantity, null: false, default: 1
      t.boolean :review_requested, null: false, default: false

      # Physical condition on arrival (e.g. "sealed", "damaged label").
      t.string :condition, limit: 64
      t.text :notes
      t.datetime :received_at

      # Set once a Review has been produced from this item. Nullable: the item
      # exists before the review does, and a review may be created directly on
      # the vintage without going through the package.
      t.references :review, null: true, foreign_key: true

      t.timestamps
    end
  end
end
