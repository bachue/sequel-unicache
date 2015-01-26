# Sequel Unicache

Read through caching library inspired by Cache Money, support Sequel 4

Read-Through: Queries by ID or any specified unique key, like `User[params[:id]]` or `User[username: 'bachue@gmail.com']`, will first look in memcache store and then look in the database for the results of that query. If there is a cache miss, it will populate the cache. As objects are created, updated, and deleted, all of the caches are automatically expired.

## Dependency

Ruby >= 2.1.0
Sequel >= 4.0
Dalli as memcache store (currently it's the only well supported driver)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sequel-unicache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sequel-unicache

## Configuration

You must configure Unicache during initialization, for Rails, create a file in config/initializers and copy the code into it will be acceptable.

```ruby
Sequel::Unicache.configure cache: Dalli::Client.new('localhost:11211'),            # Required, object to manipulate memcache, only Dalli is well supported for now
                   ttl: 60,                                                # Expiration time, by default it's 0, means won't expire
                   serialize: {|model, opts| Marshal.dump(model) },        # Serialization method, by default it's Marshal (fast, Ruby native-supported, non-portable)
                   deserialize: {|cache, opts| Marshal.load(cache) },      # Deserialization method
                   key: {|model, opts| "#{model.class.name}/{model.id}" }, # Cache key generation method
                   enabled: true,                                          # Enabled on all Sequel::Model subclasses by default
                   logger: Logger.new(STDOUT)                              # Logger, needed when debug

# Read & write global configuration by key:
Sequel::Unicache.config.ttl # 60
Sequel::Unicache.config.ttl = 20
```

## Usage

For example, cache User object:

```ruby
class User < Sequel::Model
  # by default primary key is always unique cache key, all settings will just follow global configuration
  unicache :username,                                               # username will also be an unique key (username should has unique index in database)
           if: {|user, opts| !user.deleted? }                       # don't cache it if model is deleted
           ttl: 30                                                  # Specify the cache expiration time (unit: second), will overwrite the default configuration
           cache: Dalli::Client.new('localhost:11211')              # Memcache store, will overwrite the default configuration
           serialize: {|user, opts| user.to_msgpack }               # Serialization method, will overwrite the global configuration
           deserialize: {|cache, opts| MessagePack.unpack(cache) }  # Deserialization method, will overwrite the global configuration
           key: {|user| "users/#{user.id}" }                        # Cache key generation method, will overwrite the global configuration
           logger: Logger.new(STDERR)                               # Object for log, will overwrite the global configuration

  # TODO: unicache :company_name, :department, :employee_id         # company_name, department, employee_id have combined unique index
end
```

Then it will fetch cached object in this situations:

```ruby
User[1]
User[username: 'bachue@gmail.com']
User.find 1
User.find username: 'bachue@gmail.com'

# TODO: User[company_name: 'EMC', employee_id: '12345']
# TODO: User.find company_name: 'EMC', employee_id: '12345'
# TODO: article.user
```

Cache key and expiration:

```ruby
User[1].unicache_key
User[1].expire_unicache_key
User.expire_unicache_key 1
```

You can enable or disable cache during initialization, or temporarily disable cache in a block on runtime:

```ruby
User.enable_unicache
User.disable_unicache
User.unicache_enabled?
User.without_unicache do
  User[1] # query database directly
end
```

Unicache won't expire cache until you update or delete a model and commit the transaction successfully.

## Notice

* You must call Sequel APIs as the document mentioned then cache can work.

* You must set primary key before you call any Unicache DSL if you need.

* You don't have to enable Unicache during the testing or development.

* If someone update database directly or by another project without unicache, then cache in memcache won't be expired automatically.
  You must manipulate cache manually or by another mechanism.

## Contributing

1. Fork it ( https://github.com/bachue/sequel-unicache/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
