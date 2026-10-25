# frozen_string_literal: true

# Delivery-time visibility recheck. Publication and relationships can change
# between when an event was recorded and when it is processed, so the event
# subject must still be publicly visible before any notification goes out.
#
# Wines and Producers have no publication state — they are always visible.
module Notifications
  module Visibility
    module_function

    def visible?(subject)
      return false if subject.nil?

      case subject
      when Review, Article
        subject.status == "published"
      else
        true
      end
    end
  end
end