# Distinguishes an AUTOMATIC completion (WinePackages::CheckCompletion: every
# review-requested item had a published review) from a DELIBERATE one
# (WinePackages::MarkCompleted: a reviewer completed the package even though
# reviews were still outstanding).
#
# The flag is what makes reopening safe: only auto-completed packages are
# reopened automatically when their work stops being complete (a review was
# unpublished, an item was added). A deliberate completion is never undone.
class AddAutoCompletedToWinePackages < ActiveRecord::Migration[8.1]
  def change
    add_column :wine_packages, :auto_completed, :boolean, null: false, default: false
  end
end
