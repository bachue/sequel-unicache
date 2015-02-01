module Sequel
  module Unicache
    module Finder # Provide class methods for Sequel::Model, to find cache by unicache keys
      module ClassMethods
        def primary_key_lookup pk
          if !Unicache.enabled? ||
             Unicache.unicache_suspended? ||
             dataset.joined_dataset? ||
             !@fast_pk_lookup_sql
            # If it's not a simple table, simple pk,
            # assign this job to parent class, which will call first_where to do that
            super
          else
            config = unicache_for primary_key # primary key is always unicache keys, no needs to fuzzy search
            if unicache_enabled_for? config
              find_with_cache({primary_key => pk}, config) { super }
            else
              super
            end
          end
        end

        def first_where hash
          return primary_key_lookup hash unless hash.is_a? Hash
          config = unicache_for(*hash.keys, fuzzy: true) # need fuzzy search, this function always returns enabled config
          if config
            find_with_cache(hash, config) { super }
          else
            super
          end
        end

      private

        # Find from cache first, if failed, get fallback result from block
        def find_with_cache hash, config
          cache = config.cache.get config.key.(hash, config)
          if cache
            values = config.deserialize.(cache, config)
            dataset.row_proc.call values
          else
            model = yield
            Write.write model if model
            model
          end
        end
      end
    end
  end
end
