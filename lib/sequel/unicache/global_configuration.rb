module Sequel
  module Unicache
    class GlobalConfiguration
      def initialize opts = {}
        @opts = opts
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

      module ClassMethods
        attr_reader :config

        def self.extended base
          base.instance_exec { @config = GlobalConfiguration.new }
        end

        def configure opts
          @config.set_all opts
        end
      end
    end
  end
end
