module Sequel
  module Unicache
    class Transaction
      class << self
        def install_hooks_for_unicache
          Sequel::Database.prepend InstanceMethods
        end
      end

      module InstanceMethods
        def _transaction conn, opts = Database::OPTS, &block
          super conn, opts do |conn|
            Unicache.suspend_unicache { block.call conn }
          end
        end
        private :_transaction
      end
    end
  end
end
