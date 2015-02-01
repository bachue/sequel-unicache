module Sequel
  module Unicache
    class Logger
      class << self
        %i[debug info warn error fatal unknown].each do |level|
          define_method level do |config, message = nil, &block|
            # config can be treated as a model, then fallback to model class configuration and global configuration
            config = config.class.unicache_model_configuration if config.is_a? Sequel::Model
            config.logger.send level, message, &block if config.logger
          end
        end
      end
    end
  end
end
