# Adds the typed membership column to producer_memberships (issue #191).
#
# The original create migration (20261021234637) is already applied in shared
# environments, so this is a forward migration and must never rewrite history.
#
# The column is added in three steps so an environment that still holds
# untyped rows stops with an actionable message instead of an opaque
# `null value in column "membership_type"` error:
#
#   1. add the column as nullable;
#   2. refuse to continue while any row is still untyped — issue #191 requires
#      an explicit inventory plus an approved mapping, and legacy rows must
#      never silently gain owner/manager access;
#   3. enforce NOT NULL and the three-value check constraint.
#
# Unblocking an environment with untyped rows.
#
# Issue #191 forbids silently granting owner/manager access, so this migration
# stops when it finds untyped rows unless the operator states the approved
# mapping explicitly:
#
#   PRODUCER_MEMBERSHIP_LEGACY_TYPE=manager bin/rails db:migrate
#
# `manager` is the documented mapping for legacy rows, because they already had
# full producer-edit access; `contributor` (read-only) is the conservative
# alternative. The value is whitelisted, audited in the deploy log, and applied
# only to rows that are still NULL.
class AddMembershipTypeToProducerMemberships < ActiveRecord::Migration[8.1]
  CHECK_CONSTRAINT = "chk_membership_type".freeze
  LEGACY_BACKFILL_ENV = "PRODUCER_MEMBERSHIP_LEGACY_TYPE".freeze

  def up
    add_column :producer_memberships, :membership_type, :string unless column_exists?(:producer_memberships, :membership_type)

    untyped_count = select_value(
      "SELECT COUNT(*) FROM producer_memberships WHERE membership_type IS NULL"
    ).to_i

    backfill_legacy_rows(untyped_count) if untyped_count.positive?

    change_column_null :producer_memberships, :membership_type, false
    add_check_constraint :producer_memberships,
                         "membership_type IN ('owner', 'manager', 'contributor')",
                         name: CHECK_CONSTRAINT
  end

  def down
    remove_check_constraint :producer_memberships, name: CHECK_CONSTRAINT if check_constraint_exists?(:producer_memberships, name: CHECK_CONSTRAINT)
    remove_column :producer_memberships, :membership_type if column_exists?(:producer_memberships, :membership_type)
  end

  private

  # Legacy rows were created before memberships were typed and therefore had
  # full producer-edit rights. They are never mapped automatically: the
  # operator must name an approved type.
  def backfill_legacy_rows(count)
    approved_type = ENV[LEGACY_BACKFILL_ENV].to_s
    unless %w[owner manager contributor].include?(approved_type)
      raise ActiveRecord::IrreversibleMigration, <<~MESSAGE
        Refusing to enforce producer_memberships.membership_type: #{count} row(s) are untyped.
        Inventory these rows and choose an approved mapping explicitly:

          PRODUCER_MEMBERSHIP_LEGACY_TYPE=manager bin/rails db:migrate   # keeps edit access
          PRODUCER_MEMBERSHIP_LEGACY_TYPE=contributor bin/rails db:migrate # read-only, conservative

        Legacy rows previously had full producer-edit access, so 'manager' is the
        documented mapping. The value must be owner, manager or contributor.
      MESSAGE
    end

    say "Backfilling #{count} untyped producer membership row(s) as #{approved_type}"
    execute <<~SQL
      UPDATE producer_memberships
         SET membership_type = #{quote(approved_type)}
       WHERE membership_type IS NULL
    SQL
  end
end
