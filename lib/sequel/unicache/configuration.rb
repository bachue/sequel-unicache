require "sequel/unicache/global_configuration"

module Sequel
  module Unicache
    class Configuration < GlobalConfiguration
      %i(if model_class unicache_keys).each do |attr|
        define_method(attr) { @opts[attr] }
        define_method("#{attr}=") { |val| @opts[attr] = val }
      end

      module ClassMethods
        # Configure for specfied model
      private
        def unicache *args
          opts = args.last.is_a?(Hash) ? args.pop : {}
          _initialize_unicache unless @unicache_configuration # Initialize first
          key = _normalize_key_for_unicache args
          config = Sequel::Unicache.config.to_h.merge opts
          config.merge! model_class: self, unicache_keys: key
          @unicache_configuration[key] = Configuration.new config
        end

      public
        # Read configuration for specified model
        def unicache_for *key
          _initialize_unicache unless @unicache_configuration # Initialize first
          key = _normalize_key_for_unicache key
          config = @unicache_configuration[key]
          raise "Must specify cache store for unicache #{key.inspect} of #{name}" if config && !config.cache
          config
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

        # Concept design
        # def _serialize_for_unicache *key, model
        #   config = unicache_for(*key)
        #   proc = config.serialize || ->(model, _) { Marshal.dump model }
        #   proc.(model, config)
        # end

        # def _deserialize_for_unicache *key, cache
        #   config = unicache_for(*key)
        #   proc = config.deserialize || ->(model, _) { Marshal.load cache }
        #   proc.(model, config)
        # end

        # def _generate_key_for_unicache *key, model
        #   config = unicache_for(*key)
        #   proc = config.key ||
        #            ->(hash, _) { hash.keys.sort.map {|attr| [attr, hash[attr].to_s] }.flatten.split(':') }
        #   hash = Array(config.unicache_keys).sort.inject({}) {|res, attr| res.merge attr => model[attr] }
        #   proc.(hash, config)
        # end

        def _initialize_unicache
          config = Sequel::Unicache.config.to_h.merge model_class: self, unicache_keys: primary_key
          @unicache_configuration = { primary_key => Configuration.new(config) }
        end

        def _normalize_key_for_unicache keys
          keys.size == 1 ? keys.first.to_sym : keys.sort.map(&:to_sym)
        end
      end
    end
  end
end
