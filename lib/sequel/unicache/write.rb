require 'sequel/unicache/logger'

module Sequel
  module Unicache
    class Write
      class << self
        def write model
          # If model is not completed, don't cache it
          columns, keys = model.columns, model.values.keys
          if (columns - keys).empty?
            cache = {}
            all_configs_of(model).each do |config|
              # write cache requires enabled unicache and if-condition returns true
              # otherwise will fallback to expire
              if permitted? model, config
                write_for model, config, cache
              else
                expire_for model, config
              end
            end
          end
        rescue Sequel::Error => error
          Unicache::Logger.warn model, "[Unicache] Sequel::Error happen when write cache for a model, fallback to expire. Reason: #{error.message}. Model: #{model.inspect}"
          expire model
        rescue => error
          Unicache::Logger.error model, "[Unicache] Exception happen when write cache for a model, fallback to expire. Reason: #{error.message}. Model: #{model.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.error model, "[Unicache] #{trace}"
          end
          expire model
        end

        def expire model
          all_configs_of(model).each do |config|
            expire_for model, config
          end
        rescue => error
          Unicache::Logger.fatal model, "[Unicache] Exception happen when expire cache for a model. Reason: #{error.message}. Model: #{model.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.fatal model, "[Unicache] #{trace}"
          end
        end

        def write_for model, config, results
          key = cache_key model, config
          cache = results[config.serialize]
          unless cache # if serialize was run before, use the cache
            cache = config.serialize.(model.values, config)
            results[config.serialize] = cache
          end
          config.cache.set key, cache, config.ttl
        rescue => error
          Unicache::Logger.error config, "[Unicache] Exception happen when write cache for unicache_key, fallback to expire. Reason: #{error.message}. Model: #{model.inspect}. Config: #{config.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.error config, "[Unicache] #{trace}"
          end
          expire_for model, config
        end

        def expire_for model, config
          key = cache_key model, config
          config.cache.delete key
        rescue => error
          Unicache::Logger.fatal config, "[Unicache] Exception happen when expire cache for unicache_key. Reason: #{error.message}. Model: #{model.inspect}. Config: #{config.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.fatal config, "[Unicache] #{trace}"
          end
        end

        def all_configs_of model
          model.class.send(:unicache_configurations).values
        end

        def cache_key model, config
          values = filter_keys model, config.unicache_keys
          config.key.(values, config)
        end

      private

        def filter_keys model, keys
          Array(keys).inject({}) { |hash, attr| hash.merge attr => model[attr] }
        end

        def permitted? model, config
          model.class.unicache_enabled_for?(config) &&
          (!config.if || config.if.(model, config))
        end
      end
    end
  end
end
