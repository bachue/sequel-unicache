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
          super
          Write.expire self
        end

        def after_destroy_commit
          super
          Write.expire self
        end
      end
    end
  end
end
