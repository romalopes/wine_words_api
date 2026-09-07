# Namespace for billing providers. Each provider subclass implements the
# contract that Billing::* services rely on. Providers register themselves
# via `Billing::Providers.register` so the active adapter can be resolved
# by key without hard-coding class names.
module Billing
  module Providers
    class << self
      def registry
        @registry ||= {}
      end

      def register(klass)
        registry[klass.new.provider_key] = klass
      end

      def find(key)
        registry[key.to_sym]
      end
    end
  end
end