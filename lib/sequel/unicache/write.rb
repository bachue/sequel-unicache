module Sequel
  module Unicache
    class Write
      class << self
        def write model
          # If model is not completed, won't write-through it to the cache
          columns, keys = model.columns, model.values.keys
          if (columns - keys).empty?
            cache = {}
            all_configs_of(model).each do |config|
              next if skip? model, config
              if permitted? model, config
                write_for model, config, cache if config.write_through
              else
                expire_for model, config
              end
            end
          end
          # TODO: logger
        rescue
          fail $!.message and exit! # TODO: Delete it
          # TODO: logger
        end

        def expire model
          all_configs_of(model).each do |config|
            next if skip? model, config
            expire_for model, config
          end
          # TODO: logger
        rescue
          fail $!.message and exit! # TODO: Delete it
          # TODO: logger
        end
      private
        def write_for model, config, results
          key = cache_key model, config
          cache = results[config.serialize]
          unless cache # if serialize was run before, use the cache
            cache = config.serialize.(model.values, config)
            results[config.serialize] = cache
          end
          config.cache.set key, cache, config.ttl
        end

        def expire_for model, config
          key = cache_key model, config
          config.cache.delete key
        end

        def all_configs_of model
          model.class.send(:unicache_configurations).values
        end

        def cache_key model, config
          values = filter_keys model, config.unicache_keys
          config.key.(values, config)
        end

        def filter_keys model, keys
          Array(keys).inject({}) { |hash, attr| hash.merge attr => model[attr] }
        end

        def skip? model, config
          !model.class.unicache_enabled_for?(config)
        end

        def permitted? model, config
          !config.if || config.if.(model, config)
        end
      end
    end
  end
end
