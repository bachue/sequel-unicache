require 'sequel/unicache/global_configuration'

module Sequel
  module Unicache
    class Configuration < GlobalConfiguration
      %i(if model_class unicache_keys).each do |attr|
        define_method(attr) { @opts[attr] }
        define_method("#{attr}=") { |val| @opts[attr] = val }
      end

      module ClassMethods
      private
        # Configure for specfied model
        def unicache *args
          opts = args.last.is_a?(Hash) ? args.pop : {}
          Utils.initialize_unicache_for_class self unless @unicache_class_configuration # Initialize class first
          if args.empty? # class-level configuration
            config = Unicache.config.to_h.merge opts
            @unicache_class_configuration = Configuration.new config.merge model_class: self
          else           # key-level configuration
            Utils.initialize_unicache_for_key self unless @unicache_key_configurations # Initialize key
            key = Utils.normalize_key_for_unicache args
            config = Unicache.config.to_h.merge @unicache_class_configuration.to_h.merge(opts)
            config.merge! unicache_keys: key
            @unicache_key_configurations[key] = Configuration.new config
          end

          def unicache_configurations
            Utils.initialize_unicache_for_class self unless @unicache_class_configuration # Initialize class first
            Utils.initialize_unicache_for_key self unless @unicache_key_configurations # Initialize key
            @unicache_key_configurations
          end
        end

      public
        # Read configuration for specified model
        def unicache_for *key, fuzzy: false
          Utils.initialize_unicache_for_class self unless @unicache_class_configuration # Initialize class first
          Utils.initialize_unicache_for_key self unless @unicache_key_configurations # Initialize key
          if fuzzy
            config = Utils.fuzzy_search_for key, @unicache_key_configurations
          else
            key = Utils.normalize_key_for_unicache key
            config = @unicache_key_configurations[key]
          end
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
          result = !@disable_unicache && Unicache.enabled?
          result &&= key.first.is_a?(Configuration) ? key.first.enabled : unicache_for(*key).enabled
          result
        end

        def without_unicache
          origin, @disable_unicache = @disable_unicache, true
          yield
        ensure
          @disable_unicache = origin
        end

        class Utils
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

          class << self
            def initialize_unicache_for_class model_class
              model_class.instance_exec do
                class_config = Unicache.config.to_h.merge model_class: model_class
                @unicache_class_configuration = Configuration.new class_config
              end
              Hook.install_hooks_for_unicache
            end

            def initialize_unicache_for_key model_class
              model_class.instance_exec do
                pk_config = @unicache_class_configuration.to_h.merge unicache_keys: model_class.primary_key
                @unicache_key_configurations = { primary_key => Configuration.new(pk_config) }
              end
            end

            def normalize_key_for_unicache keys
              keys.size == 1 ? keys.first.to_sym : keys.sort.map(&:to_sym)
            end

            # fuzzy search will always search for enabled config
            def fuzzy_search_for keys, configs
              _, result = configs.detect do |cache_key, config|
                            match = if cache_key.is_a? Array
                                      cache_key & keys == cache_key
                                    else
                                      keys.include? cache_key
                                    end
                            match & config.enabled
                          end
              result
            end
          end
        end
      end
    end
  end
end
