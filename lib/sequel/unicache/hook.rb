require 'sequel/unicache/write'
require 'sequel/unicache/expire'

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
          Write.expire self if Unicache.enabled?
          @_unicache_previous_values = nil
          super
        end

        def after_rollback
          @_unicache_previous_values = nil
          super
        end

        def after_destroy_commit
          Write.expire self if Unicache.enabled?
          super
        end

        def before_update
          # Store all previous values, to be expired
          @_unicache_previous_values = initial_values.merge(@_unicache_previous_values || {})
          super
        end
      end
    end
  end
end
