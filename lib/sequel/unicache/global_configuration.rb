module Sequel
  module Unicache
    class GlobalConfiguration
      def initialize opts = {}
        @opts = default_config.merge opts
      end

      def set_all opts
        @opts.merge! opts
      end

      def to_h
        @opts
      end

      %i(cache ttl serialize deserialize key enabled logger).each do |attr|
        define_method(attr) { @opts[attr] }
        define_method("#{attr}=") { |val| @opts[attr] = val }
      end

    private

      def default_config
        { serialize: ->(values, _) { Marshal.dump values },
          deserialize: ->(cache, _) { Marshal.load cache },
          key: ->(hash, _) { hash.keys.sort.map {|key| [key, hash[key].to_s] }.flatten.split(':') } }
      end

      module ClassMethods
        attr_reader :config

        def self.extended base
          base.instance_exec { @config = GlobalConfiguration.new }
        end

        def configure opts
          @config.set_all opts
        end

        def enable
          @disabled = false
        end

        def disable
          @disabled = true
        end

        def enabled?
          !@disabled
        end
      end
    end
  end
end
