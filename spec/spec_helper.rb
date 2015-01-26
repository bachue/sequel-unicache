require 'bundler'
require 'erb'
require 'logger'
require 'yaml'

begin
  ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', __dir__)
  Bundler.setup
rescue Bundler::GemNotFound
  abort "Bundler couldn't find some gems.\n" \
        'Did you run `bundle install`?'
end

require 'sequel/unicache'
require 'active_support/all'
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
end

RSpec.configure do |config|
  config.include Helpers
end
