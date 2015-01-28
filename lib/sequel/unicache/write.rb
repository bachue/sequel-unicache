module Sequel
  module Unicache
    class Write
      class << self
        def write model
          # If model is not completed, won't write-through it to the cache
          columns, keys = model.columns, model.values.keys
          if (columns - keys).empty?
            configs = model.class.send(:unicache_configurations).values
            results = {}
            configs.each do |config|
              next if skip? model, config
              values = filter_keys model, config.unicache_keys
              key = config.key.(values, config)
              cache = results[config.serialize]
              unless cache # if serialize was run before, use the cache
                cache = config.serialize.(model.values, config)
                results[config.serialize] = cache
              end
              config.cache.set key, cache, config.ttl
            end
          end
          # TODO: logger
        rescue
          fail $!.message and exit! # TODO: Delete it
          # TODO: logger
        end
      private
        def filter_keys model, keys
          Array(keys).inject({}) { |hash, attr| hash.merge attr => model[attr] }
        end

        def skip? model, config
          !model.class.unicache_enabled_for?(config) ||
          !config.write_through ||
          config.if && !config.if.(model, config)
# TODO: if config.if returns false/nil, should still calculate the key and expire it
        end
      end
    end
  end
end
