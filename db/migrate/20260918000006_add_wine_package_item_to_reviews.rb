# Additive link from a Review back to the package item it fulfilled.
#
# Nullable by design: every existing Review stays valid, and reviews created
# directly on a vintage (the long-standing workflow) simply have no item. This
# is what lets a review "complete" its package item without touching the
# existing Review create/update paths.
class AddWinePackageItemToReviews < ActiveRecord::Migration[8.1]
  def change
    add_reference :reviews, :wine_package_item, null: true, foreign_key: true
  end
end
