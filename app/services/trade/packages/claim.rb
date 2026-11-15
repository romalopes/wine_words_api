module Trade
  module Packages
    # Links a package to the signed-in user (IDENTITY_206 Phase 5).
    #
    # The claim token is the package's guest token, obtained from the claim
    # link emailed to an existing-email submitter (or shown on the confirmation
    # page for a new-email submitter). Claiming:
    #   * sets `submitter_id` (the TRADE ownership link — never requested_by);
    #   * revokes the guest token (single-claim semantics);
    #   * records an auditable `package_claimed` event.
    #
    # An already-claimed package is idempotently returned when the claimant is
    # the owner and rejected otherwise — no cross-user takeover, and no
    # disclosure of WHO owns another package.
    class Claim
      def self.call(package:, user:, guest_token:)
        new(package, user: user, guest_token: guest_token).call
      end

      def initialize(package, user:, guest_token:)
        @package = package
        @user = user
        @guest_token = guest_token
      end

      def call
        raise Error, "claim token is invalid or has expired" unless package.guest_token_valid?(guest_token)

        if package.claimed?
          if package.submitter_id == user.id
            return package
          else
            raise Error, "this package has already been claimed"
          end
        end

        ActiveRecord::Base.transaction do
          package.update!(submitter: user)
          package.revoke_guest_token!
          package.wine_package_events.create!(
            event_type: "package_claimed",
            actor: user,
            visibility: "shared",
            occurred_at: Time.current,
            metadata: {}
          )
        end
        package
      end

      private

      attr_reader :package, :user, :guest_token
    end
  end
end