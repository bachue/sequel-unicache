require 'sequel/unicache/write'

module Sequel
  module Unicache
    class Expire
      module InstanceMethods # Provide instance methods for Sequel::Model, to expire cache
        def refresh
          model = super
          Write.expire model if Unicache.enabled?
          model
        end
      end
    end
  end
end
