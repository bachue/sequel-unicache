require 'sequel'
require 'sequel/unicache/version'
require 'sequel/unicache/global_configuration'
require 'sequel/unicache/configuration'
require 'sequel/unicache/finder'

module Sequel
  module Unicache
    extend GlobalConfiguration::ClassMethods
  end

  class Model
    extend Unicache::Configuration::ClassMethods
    extend Unicache::Finder::ClassMethods
  end
end
