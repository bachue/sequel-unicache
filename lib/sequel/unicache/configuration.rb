require 'sequel/unicache/global_configuration'
require 'sequel/unicache/hook'
require 'sequel/unicache/transaction'

module Sequel
  module Unicache
    class ModelConfiguration < GlobalConfiguration
      %i(model_class version).each do |attr|
        define_method(attr) { @opts[attr] }
        define_method("#{attr}=") { |val| @opts[attr] = val }
      end
    end

    class Configuration < ModelConfiguration
      %i(if unicache_keys).each do |attr|
        define_method(attr) { @opts[attr] }
        define_method("#{attr}=") { |val| @opts[attr] = val }
      end
      undef_method :version
      undef_method :version=

      module ClassMethods
      private
        # Configure for specfied model
        def unicache *args
          opts = args.last.is_a?(Hash) ? args.pop : {}
          Utils.initialize_unicache_for_class self unless @unicache_model_configuration # Initialize class first
          if args.empty? # class-level configuration
            config = Unicache.config.to_h.merge opts
            config = {version: 1}.merge(config).merge model_class: self
            @unicache_model_configuration = ModelConfiguration.new config
          else           # key-level configuration
            Utils.initialize_unicache_for_key self unless @unicache_key_configurations # Initialize key
            key = Utils.normalize_key_for_unicache args
            config = Unicache.config.to_h.merge @unicache_model_configuration.to_h.merge(opts)
            config.delete :version
            config.merge! unicache_keys: key
            @unicache_key_configurations[key] = Configuration.new config
          end
        end

        def initialize_unicache
          Utils.initialize_unicache_for_class self unless @unicache_model_configuration # Initialize class first
          Utils.initialize_unicache_for_key self unless @unicache_key_configurations # Initialize key
        end

      public
        # Read configuration for specified model
        def unicache_for *key, fuzzy: false
          initialize_unicache
          if fuzzy
            config = Utils.fuzzy_search_for key, @unicache_key_configurations
          else
            key = Utils.normalize_key_for_unicache key
            config = @unicache_key_configurations[key]
          end
          config
        end

        def unicache_enabled_for? *key # config.enabled must be true, config.cache must be existed
          if key.first.is_a?(Configuration)
            config = key.first
          else
            config = unicache_for(*key)
          end
          config.cache && config.enabled if config
        end

        def unicache_model_configuration
          initialize_unicache
          @unicache_model_configuration
        end

        def unicache_configurations
          initialize_unicache
          @unicache_key_configurations
        end

        class Utils
          class << self
            def initialize_unicache_for_class model_class
              model_class.instance_exec do
                plugin :dirty
                class_config = Unicache.config.to_h.merge model_class: model_class, version: 1
                @unicache_model_configuration = ModelConfiguration.new class_config
              end
              Hook.install_hooks_for_unicache
              Transaction.install_hooks_for_unicache
            end

            def initialize_unicache_for_key model_class
              model_class.instance_exec do
                @unicache_key_configurations = {}
                if primary_key
                  pk_config = @unicache_model_configuration.to_h.merge unicache_keys: model_class.primary_key
                  @unicache_key_configurations[primary_key] = Configuration.new pk_config
                end
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
                            match & config.cache && config.enabled
                          end
              result
            end
          end
        end
      end
    end
  end
end
