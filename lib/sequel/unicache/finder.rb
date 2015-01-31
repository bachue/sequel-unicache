module Sequel
  module Unicache
    module Finder # Provide class methods for Sequel::Model, to find cache by unicache keys
      module ClassMethods
        def primary_key_lookup pk
          if Unicache.unicache_suspended? ||
             dataset.joined_dataset? ||
             !@fast_pk_lookup_sql
            # If it's not a simple table, simple pk,
            # assign this job to parent class, which will call first_where to do that
            super
          else
            config = unicache_for primary_key # primary key is always unicache keys, no needs to fuzzy search
            if unicache_enabled_for? config
              key = config.key.({primary_key => pk}, config)
              cache = config.cache.get key
              if cache
                dataset.row_proc.call config.deserialize.(cache, config)
              else
                model = super # cache not found
                Write.write model if model
                model
              end
            else
              super
            end
          end
        end
      end
    end
  end
end
