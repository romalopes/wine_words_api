# IDENTITY_214 bug fix backfill.
#
# Packages marked "arrived" before the review-scoping fix never got their
# trade-submission lines flagged as review-requested (mark_arrived! now does
# this automatically). Align existing data with the new lifecycle so those
# packages show "Pending"/"Requested" badges and working "Create review"
# buttons, and their review progress counts include every line.
class BackfillReviewRequestedForArrivedTradePackages < ActiveRecord::Migration[8.1]
  def up
    package_ids = WinePackage
                    .where(source: "trade_submission", status: %w[arrived reviewing completed])
                    .select(:id)

    updated = WinePackageItem
                .where(wine_package_id: package_ids, review_requested: false)
                .update_all(review_requested: true)

    say "Flagged #{updated} trade package line(s) as review-requested"
  end

  def down
    # Not reversible: pre-existing explicit request flags cannot be
    # distinguished from backfilled ones, and un-flagging lines could block
    # reviews that were legitimately requested. Data-only backfill.
    raise ActiveRecord::IrreversibleMigration
  end
end
