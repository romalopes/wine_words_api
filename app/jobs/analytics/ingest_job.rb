module Analytics
  class IngestJob < ApplicationJob
    queue_as :default

    def perform(**attrs)
      attrs = attrs.symbolize_keys
      if (user_id = attrs.delete(:current_user_id))
        attrs[:current_user] = User.find_by(id: user_id)
      end
      Analytics::Ingest.call(**attrs)
    end
  end
end
