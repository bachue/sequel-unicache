# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel/unicache/version'

Gem::Specification.new do |spec|
  spec.name          = "sequel-unicache"
  spec.version       = Sequel::Unicache::VERSION
  spec.authors       = ['Bachue Zhou']
  spec.email         = ['bachue.shu@gmail.com']
  spec.summary       = 'Write through and Read through caching library inspired by Cache Money, support Sequel 4'
  spec.description   = <<-SUMMARY
Read through caching library inspired by Cache Money, support Sequel 4

Read-Through: Queries by ID or any specified unique key, like `User[params[:id]]` or `User[username: 'bachue@gmail.com']`, will first look in memcache store and then look in the database for the results of that query. If there is a cache miss, it will populate the cache. As objects are created, updated, and deleted, all of the caches are automatically expired.
  SUMMARY
  spec.homepage      = 'https://github.com/bachue/sequel-unicache'
  spec.license       = 'GPLv2'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.1'
  spec.add_runtime_dependency 'sequel', '~> 4.0'
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'dalli'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-doc'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'activesupport'
end
