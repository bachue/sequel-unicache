module Sequel
  module Unicache
    class GlobalConfiguration
      def initialize opts = {}
        @opts = default_config.merge opts
      end

      def set opts
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
          key: ->(hash, _) {
            hash.keys.sort.map {|key| [key, hash[key]] }.flatten.
                 map {|str| str.to_s.gsub(':', '\:') }.join(':')
          },
          enabled: true }
      end

      module ClassMethods
        attr_reader :config

        def self.extended base
          base.instance_exec { @config = GlobalConfiguration.new }
        end

        def configure opts
          @config.set opts
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

        def unicache_suspended?
          Thread.current[:unicache_suspended]
        end

        def suspend_unicache
          if block_given?
            origin, Thread.current[:unicache_suspended] = Thread.current[:unicache_suspended], true
            yield
          else
            origin = true
          end
        ensure
          Thread.current[:unicache_suspended] = origin
        end

        def unsuspend_unicache
          Thread.current[:unicache_suspended] = false
        end
      end
    end
  end
end
