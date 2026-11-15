# Trade portal (IDENTITY_206 Phase 4 UX): the submission vintage picker offers
# "NV (Non vintage)" and "MV (Multi vintage)" alongside calendar years. The
# integer `proposed_vintage_year` keeps storing real years only; NV/MV are
# recorded here as a short label with a nil year, so no fake years are invented.
class AddSnapshotVintageLabelToWinePackageItems < ActiveRecord::Migration[8.1]
  def change
    add_column :wine_package_items, :snapshot_vintage_label, :string, limit: 8
  end
end
