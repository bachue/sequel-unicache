module Sequel
  module Unicache
    class WriteThrough
      class << self
        def write model
          # If model is not completed, won't write-through it to the cache
          columns, keys = model.columns, model.values.keys
          if (columns - keys).empty?
            config = model.class.unicache_for(*keys, fuzzy: true)
            # TODO: Should write to all possible keys
            if config && model.class.unicache_enabled_for?(config)
              if !config.if || config.if.(model, config)
                values = filter_keys model, config.unicache_keys
                key = config.key.(values, config)
                cache = config.serialize.(model.values, config)
                config.cache.set key, cache, config.ttl
              end
            end
          end
          # TODO: logger
        rescue
          fail $!.message and exit!
          # TODO: logger
        end
      private
        def filter_keys model, keys
          Array(keys).inject({}) {|hash, attr|
            hash.merge attr => model[attr]
          }
        end
      end
    end
  end
end
