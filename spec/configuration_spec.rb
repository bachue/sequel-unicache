require 'spec_helper'

describe Sequel::Unicache::Configuration do
  it 'should be true' do
    expect(Sequel::Unicache.config).to be_kind_of Sequel::Unicache::Configuration
  end

  it 'can configure' do
    logger = Logger.new(STDERR)
    serialize_proc = ->(model, opts) { Marshal.dump model }
    deserialize_proc = ->(cache, opts) { Marshal.load cache }

    Sequel::Unicache.configure cache: memcache,
                               ttl: 30,
                               enabled: true,
                               logger: logger

    expect(Sequel::Unicache.config.cache).to be cache
    expect(Sequel::Unicache.config.ttl).to be 30
    expect(Sequel::Unicache.config.enabled).to be true
    expect(Sequel::Unicache.config.logger).to be logger

    Sequel::Unicache.config.serialize = serialize_proc
    Sequel::Unicache.config.deserialize = deserialize_proc

    expect(Sequel::Unicache.config.serialize).to be serialize_proc
    expect(Sequel::Unicache.config.deserialize).to be deserialize_proc
  end
end
