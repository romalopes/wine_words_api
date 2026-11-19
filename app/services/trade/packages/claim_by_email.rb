module Trade
  module Packages
    # Claims an UNCLAIMED trade submission for the signed-in user when the
    # contact email on the submission matches the account email.
    #
    # This covers the "submitted as a guest, then logged in" path: the package
    # was created with submitter_id = nil, so the ownership check on
    # /trade/packages/:id would 404 forever. Matching on the submitted email is
    # safe — an already-claimed package is never touched (idempotent for the
    # owner, and a no-disclosure 404 for everyone else, enforced upstream).
    class ClaimByEmail
      def self.call(package:, user:)
        new(package, user: user).call
      end

      def initialize(package, user:)
        @package = package
        @user = user
      end

      def call
        return package if package.submitter_id == user.id

        raise Error, "this package has already been claimed" if package.claimed?
        raise Error, "this submission cannot be linked to this account" unless email_matches?

        ActiveRecord::Base.transaction do
          package.update!(submitter: user, created_by: package.created_by || user)
          unless package.wine_package_events.exists?(event_type: "package_claimed")
            package.wine_package_events.create!(
              event_type: "package_claimed",
              actor: user,
              visibility: "shared",
              occurred_at: Time.current,
              metadata: { claimed_via: "email" }
            )
          end
        end
        package
      end

      private

      attr_reader :package, :user

      def email_matches?
        submitted = package.contact_snapshot["email"].to_s.downcase.strip
        return false if submitted.blank?

        submitted == user.email.to_s.downcase.strip
      end
    end
  end
end
