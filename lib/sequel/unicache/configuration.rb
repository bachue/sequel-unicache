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
          key = key.size == 1 ? key.first : key.sort
          @unicache_configuration[key] = Configuration.new Sequel::Unicache.config.to_h.merge opts
        end

        # Read configuration for specified model
        def unicache_for *key
          _initialize_unicache unless @unicache_configuration # Initialize first
          key = key.size == 1 ? key.first : key.sort
          @unicache_configuration[key]
        end

        def _initialize_unicache
          @unicache_configuration = { primary_key => Configuration.new(Sequel::Unicache.config.to_h) }
        end

        private :_initialize_unicache
      end
    end
  end
end
