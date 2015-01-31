[![Build Status](https://travis-ci.org/bachue/sequel-unicache.svg)](https://travis-ci.org/bachue/sequel-unicache)

# Sequel Unicache

Read through caching library inspired by Cache Money, support Sequel 4

Read-Through: Queries by ID or any specified unique key, like `User[params[:id]]` or `User[username: 'bachue@gmail.com']`, will first look in memcache store and then look in the database for the results of that query. If there is a cache miss, it will populate the cache. As objects are updated and deleted, all of the caches are automatically expired.

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
Sequel::Unicache.configure cache: Dalli::Client.new('localhost:11211'),       # Required, object to manipulate memcache,
                                                                              # only Dalli is well supported for now
                   ttl: 60,                                                   # Expiration time, by default it's 0, means won't expire
                   serialize: {|values, opts| Marshal.dump(values) },         # Serialization method,
                                                                              # by default it's Marshal (fast, Ruby native-supported, non-portable)
                   deserialize: {|cache, opts| Marshal.load(cache) },         # Deserialization method
                   key: {|hash, opts| "#{opts.model_class.name}/{hash[:id]}" },    # Cache key generation method
                   enabled: true,                                             # Enabled on all Sequel::Model subclasses by default
                   logger: Logger.new(STDOUT)                                 # Logger, needed when debug

# Read & write global configuration by key:
Sequel::Unicache.config.ttl # 60
Sequel::Unicache.config.ttl = 20
```

Unicache configuration has 3 levels, global-level, configuration-level and key-level, which is the most flexible.

## Usage

For example, cache User object:

```ruby
class User < Sequel::Model
  # class level configuration, for all unicache keys of the model
  unicache if: {|user, opts| !user.deleted? },                      # don't cache it if model is deleted
           ttl: 30,                                                 # Specify the cache expiration time (unit: second), will overwrite the default configuration
           cache: Dalli::Client.new('localhost:11211'),             # Memcache store, will overwrite the default configuration
           serialize: {|values, opts| values.to_msgpack },          # Serialization method, will overwrite the global configuration
           deserialize: {|cache, opts| MessagePack.unpack(cache) }, # Deserialization method, will overwrite the global configuration
           key: {|hash, opts| "users/#{hash[:id]}" },               # Cache key generation method, will overwrite the global configuration
           logger: Logger.new(STDERR),                              # Object for log, will overwrite the global configuration

  # by default primary key is always unique cache key, all settings will just follow global configuration and class configuration
  # key level configuration for username
  unicache :username,                                               # username will also be an unique key (username should has unique index in database, and never be null)
           ttl: 60                                                  # will override the global and class configuration

  unicache :company_name, :department, :employee_id                 # company_name, department, employee_id have combined unique index
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
User[1].unicache_key only: [:id]
User[1].expire_unicache_key
User[1].expire_unicache_key except: [:id]
User.expire_unicache_key 1
```

You can temporarily suspend / unsuspend read-through on runtime:

```ruby
# These three APIs are thread-safe
Sequel::Unicache.suspend_unicache
Sequel::Unicache.unsuspend_unicache
Sequel::Unicache.suspend_unicache do
  User[1] # query database directly, and won't write model into cache
end
```

Even if read-through is suspended, model modification or deletion will still expire the cache, don't worry about it.

Within a transaction, read-through will also be suspended, then you can query data from transaction rather than cache.

You're not supposed to enable Unicache during the testing or development. These methods can help to enable or disable all Unicache features.

```ruby
# Notice: These three APIs are not thread-safe, do not call then on runtime!
Sequel::Unicache.enable
Sequel::Unicache.disable
Sequel::Unicache.enabled?
```

But if Unicache is disabled, no expiration any more, cache could be dirty because of that.

Unicache won't expire cache until you create, update or delete a model and commit the transaction successfully.

If you reload a model, cache will also be updated.

## Notice

* Database must support transaction.

* You must call Sequel APIs as the document mentioned then cache can work.

* You must set primary key before you call any Unicache DSL if you need.

* If you want to configure both class-level and key-level for a model, configure class-level first.

* If someone update database by SQL directly (even Sequel APIs like `User.insert`, `user.delete` or `User.db.[]` won't be supported) or by another project without unicache, then cache in memcache won't be expired automatically.
  You must expire cache manually or by another mechanism.

## Contributing

1. Fork it ( https://github.com/bachue/sequel-unicache/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
