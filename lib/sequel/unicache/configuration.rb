require "sequel/unicache/global_configuration"

module Sequel
  module Unicache
    class Configuration < GlobalConfiguration
      define_method(:if) { @opts[:if] }
      define_method(:if=) { |val| @opts[:if] = val }

      module ClassMethods
        # Configure for specfied model
        def unicache *key, opts
          _initialize_unicache unless @unicache_configuration # Initialize first
          key = _normalize_key_for_unicache key
          @unicache_configuration[key] = Configuration.new Sequel::Unicache.config.to_h.merge opts
        end

        # Read configuration for specified model
        def unicache_for *key
          _initialize_unicache unless @unicache_configuration # Initialize first
          key = _normalize_key_for_unicache key
          @unicache_configuration[key]
        end

        def enable_unicache_for *key
          unicache_for(*key).enabled = true
        end

        def disable_unicache_for *key
          unicache_for(*key).enabled = false
        end

        def unicache_enabled_for? *key
          !@disable_unicache && unicache_for(*key).enabled
        end

        def without_unicache
          @disable_unicache = true
          yield
        ensure
          @disable_unicache = nil
        end

      private

        def _initialize_unicache
          @unicache_configuration = { primary_key => Configuration.new(Sequel::Unicache.config.to_h) }
        end

        def _normalize_key_for_unicache keys
          keys.size == 1 ? keys.first : keys.sort
        end
      end
    end
  end
end
