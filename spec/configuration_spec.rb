require 'spec_helper'

describe Sequel::Unicache::Configuration do
  before :each do
    Sequel::Unicache.configure cache: memcache, enabled: true, ttl: 120
  end

  it 'should configure primary key as unicache' do
    expect(User.unicache_for(:id)).to be_kind_of Sequel::Unicache::Configuration
    expect(User.unicache_for(:id).cache).to be memcache
    expect(User.unicache_for(:id).enabled).to be true
    expect(User.unicache_for(:id).ttl).to be 120
  end

  it 'should configure primary key as unicache even primary key is changed' do
    User.set_primary_key [:company_name, :department, :employee_id]
    expect(User.unicache_for(:company_name, :department, :employee_id)).to be_kind_of Sequel::Unicache::Configuration
    expect(User.unicache_for(:department, :company_name, :employee_id).cache).to be memcache
    expect(User.unicache_for(:employee_id, :department, :company_name).enabled).to be true
    expect(User.unicache_for(:department, :employee_id, :company_name).ttl).to be 120
  end

  it 'can configure for primary key manually' do
    condition_proc = ->(model, opts) { model.deleted? }
    User.unicache :id, enabled: false, if: condition_proc
    expect(User.unicache_for(:id)).to be_kind_of Sequel::Unicache::Configuration
    expect(User.unicache_for(:id).cache).to be memcache
    expect(User.unicache_for(:id).enabled).to be false
    expect(User.unicache_for(:id).ttl).to be 120
    expect(User.unicache_for(:id).if).to be condition_proc
  end

  it 'can configure for another unicache' do
    serialize_proc = ->(model, opts) { JSON.dump model }
    deserialize_proc = ->(cache, opts) { JSON.load cache }
    User.unicache :department, :employee_id, :company_name, ttl: 60,
                  serialize: serialize_proc, deserialize: deserialize_proc
    expect(User.unicache_for(:company_name, :department, :employee_id)).to be_kind_of Sequel::Unicache::Configuration
    expect(User.unicache_for(:department, :company_name, :employee_id).cache).to be memcache
    expect(User.unicache_for(:employee_id, :department, :company_name).enabled).to be true
    expect(User.unicache_for(:department, :employee_id, :company_name).serialize).to be serialize_proc
    expect(User.unicache_for(:company_name, :employee_id, :department).deserialize).to be deserialize_proc
  end
end
