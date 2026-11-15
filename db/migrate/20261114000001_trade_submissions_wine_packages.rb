# Trade portal submissions (IDENTITY_206): WinePackage extensions for public
# trade submissions.
#
# Design notes (Phase 1 final decisions):
#   * `producer_id` becomes nullable — a trade submitter may represent a producer
#     that does not exist in the catalogue yet. Producer-facing validations stay
#     conditional on the package source.
#   * `submitter_id` is the TRADE contact (winery/importer/agent) and is distinct
#     from `requested_by_id` (the producer member of issue #199).
#   * `contact_snapshot` is an immutable JSONB snapshot of the submission form's
#     contact step — no separate contacts table.
#   * Guest tokens give an anonymous submitter read access to exactly one package:
#     hashed at rest (`guest_token_digest`), expiring, revocable.
#   * `shipping_address` JSONB is collected AFTER payment (Phase 12) and mirrors
#     the contact_snapshot pattern.
#   * `shipping_override_*` records the auditable Admin payment-gate override.
class TradeSubmissionsWinePackages < ActiveRecord::Migration[8.1]
  def change
    change_table :wine_packages, bulk: true do |t|
      t.bigint :submitter_id
      t.jsonb :contact_snapshot
      t.string :guest_token_digest
      t.datetime :guest_token_expires_at
      t.datetime :guest_token_revoked_at
      t.jsonb :shipping_address
      t.bigint :shipping_override_by_id
      t.string :shipping_override_reason, limit: 255
      t.datetime :shipping_override_at
    end

    # A trade submission has no producer yet.
    change_column_null :wine_packages, :producer_id, true

    add_index :wine_packages, :submitter_id
    add_index :wine_packages, :guest_token_digest
    add_foreign_key :wine_packages, :users, column: :submitter_id
    add_foreign_key :wine_packages, :users, column: :shipping_override_by_id
  end
end