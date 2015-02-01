require 'sequel/unicache/write'

module Sequel
  module Unicache
    class Hook # Provide after_commit & after_destroy_commit to update cache
      class << self
        def install_hooks_for_unicache
          Sequel::Model.include InstanceMethods
        end
      end

      module InstanceMethods
        def after_commit
          if Unicache.enabled?
            Write.expire self
            @_unicache_previous_values = nil
          end
          super
        end

        def after_rollback
          @_unicache_previous_values = nil if Unicache.enabled?
          super
        end

        def after_destroy_commit
          if Unicache.enabled?
            Write.expire self
            @_unicache_previous_values = nil
          end
          super
        end

        def after_destroy_rollback
          @_unicache_previous_values = nil if Unicache.enabled?
          super
        end

        def before_destroy
          if Unicache.enabled? && !Write.check_completeness?(self) && primary_key
            @_unicache_previous_values = self.class.with_pk(pk).values
          end
          super
        end

        def before_update
          if Unicache.enabled?
            # Store all previous values, to be expired
            @_unicache_previous_values = initial_values.merge(@_unicache_previous_values || {})
          end
          super
        end
      end
    end
  end
end
