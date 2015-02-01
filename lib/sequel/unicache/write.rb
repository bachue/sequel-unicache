require 'sequel/unicache/logger'

module Sequel
  module Unicache
    class Write
      class << self
        def write model
          # If model is not completed, don't cache it
          if (model.columns - model.keys).empty?
            cache = {}
            unicache_configurations(model).each_value do |config|
              continue unless enabled? model, config # if unicached is disabled, do nothing
              # write cache requires if-condition returns true
              # otherwise will fallback to expire
              if permitted? model, config
                write_for model, config, cache unless suspended? # must be allowed to write cache
              else
                expire_for model, config
              end
            end
          end
        rescue => error
          Unicache::Logger.fatal model, "[Unicache] Exception happen when write cache for a model, fallback to expire. Reason: #{error.message}. Model: #{model.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.fatal model, "[Unicache] #{trace}"
          end
          expire model
        end

        def expire model, force: false
          configs = unicache_configurations model
          reload model unless check_completeness? model, configs
          restore_previous model do # restore to previous values temporarily
            # Unicache must be enabled then do expiration
            configs.each_value { |config| expire_for model, config if force || enabled?(model, config) }
          end
        rescue => error
          Unicache::Logger.fatal model, "[Unicache] Exception happen when expire cache for a model. Reason: #{error.message}. Model: #{model.inspect}"
          error.backtrace.each do |trace|
            Unicache::Logger.fatal model, "[Unicache] #{trace}"
          end
        end

        def check_completeness? model, configs = unicache_configurations(model)
          all_unicache_keys = configs.keys.flatten.uniq
          model_keys = model.keys
          all_unicache_keys.all? {|key| model_keys.include? key }
        end

      private

        def reload model
          model.reload
        rescue Sequel::Error => err
          raise unless err.message == 'Record not found'
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

        def unicache_configurations model
          model.class.unicache_configurations
        end

        def cache_key model, config
          values = select_keys model, config.unicache_keys
          config.key.(values, config)
        end

        def restore_previous model
          previous_changes = model.instance_variable_get :@_unicache_previous_values
          unless previous_changes.nil? || previous_changes.empty?
            origin = select_keys model, previous_changes.keys
            model.set_all previous_changes
          end
          yield
        ensure
          model.set_all origin if origin
        end

        def select_keys model, keys
          Array(keys).inject({}) { |hash, attr| hash.merge attr => model[attr] }
        end

        def enabled? model, config
          model.class.unicache_enabled_for? config
        end

        def suspended?
          Unicache.unicache_suspended?
        end

        def permitted? model, config
          !config.if || config.if.(model, config)
        end
      end
    end
  end
end
