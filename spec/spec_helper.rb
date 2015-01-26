require 'bundler'

begin
  ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', __dir__)
  Bundler.setup
rescue Bundler::GemNotFound
  abort "Bundler couldn't find some gems.\n" \
        'Did you run `bundle install`?'
end

require 'erb'
require 'logger'
require 'yaml'

require 'sequel/unicache'
require 'active_support/core_ext/hash/keys'
require 'dalli'
require 'pry'

module Helpers
  def memcache
    @cache ||= begin
      memcache_config = YAML.load(ERB.new(File.read(File.expand_path('memcache.yml', __dir__))).result)

      hosts = memcache_config['servers'].map {|server| "#{server['host']}:#{server['port']}" }
      opts = memcache_config['options'] || {}

      client = Dalli::Client.new hosts, opts.symbolize_keys
      client.alive!
      client
    rescue Dalli::RingError
      abort "Memcache Server is unavailable."
    rescue Errno::ENOENT
      abort "You must configure memcache in spec/memcache.yml before the testing.\n" \
                  "Copy from spec/memcache.yml.example then modify base on it will be recommended."
    end
  end

  def initialize_models
    model = Class.new Sequel::Model
    model.set_dataset database[:users]
    Object.send :const_set, :User, model
  end

  def clear_models
    Object.send :remove_const, :User
  end

  def database
    @database ||= begin
      db = Sequel.sqlite
      db.run <<-SQL
        CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT,
                           username VARCHAR NOT NULL, password VARCHAR,
                           company_name VARCHAR NOT NULL, department VARCHAR NOT NULL,
                           employee_id INTEGER NOT NULL);
      SQL
      db[:users].insert username: 'bachue@gmail.com', password: 'bachue',
                        company_name: 'EMC', department: 'Mozy', employee_id: 12345
      db
    end
  end

  def reset_database
    return unless @database
    remove_instance_variable :@database
  end

  def reset_global_configuration
    Sequel::Unicache.instance_variable_set :@opts, {}
  end
end

RSpec.configure do |config|
  config.include Helpers

  config.before :each do
    memcache.flush_all
    initialize_models
  end

  config.after :each do
    reset_database
    clear_models
    reset_global_configuration
  end
end
