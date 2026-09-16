# External authentication identities (Google / Apple / Microsoft / Facebook).
#
# A UserIdentity is *how* somebody authenticated; User remains the canonical
# application identity. Keeping identities in their own table means:
#   * User keeps exactly one Account, one role set and one subscription,
#     regardless of how many providers the person connects;
#   * no provider-specific columns are ever added to users/accounts;
#   * one provider subject can never belong to two Users.
class CreateUserIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true

      # "google" | "apple" | "microsoft" | "facebook" (string-backed enum).
      t.string :provider, null: false, limit: 32
      # The provider's *stable* subject identifier (Google sub, Apple sub,
      # Microsoft sub, Facebook id). Never the email: emails can change, be
      # private relays (Apple), or be absent entirely.
      t.string :provider_uid, null: false, limit: 255
      # Snapshot of the email the provider returned. Informational only — used
      # for display and for the documented account-linking policy.
      t.string :email, limit: 255

      t.timestamps
    end

    # Mandatory: the same provider identity must never belong to two Users.
    # This index is the ultimate guard against identity hijacking (the model
    # validation is only a friendly, race-prone pre-check).
    add_index :user_identities, [ :provider, :provider_uid ],
              unique: true,
              name: "index_user_identities_on_provider_and_provider_uid"

    # One identity per provider per User: connecting "Google" twice is a
    # no-op/conflict rather than a second indistinguishable row.
    add_index :user_identities, [ :user_id, :provider ],
              unique: true,
              name: "index_user_identities_on_user_id_and_provider"
  end
end
