require 'spec_helper'

describe Sequel::Unicache::WriteThrough do
  before :each do
    Sequel::Unicache.configure cache: memcache, enabled: true, ttl: 120
  end

  it 'can write through cache into memcache after create a model' do
    user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                       company_name: 'EMC', department: 'Mozy', employee_id: 23456
    cache = memcache.get("id:#{user.id}")
    expect(cache).not_to be_nil
    expect(Marshal.load(cache)).to eq user.values
  end

  it 'can serialize model into specified format' do
    User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_json } }
    user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                       company_name: 'EMC', department: 'Mozy', employee_id: 23456
    cache = memcache.get("id:#{user.id}")
    expect(cache).not_to be_nil
    expect(JSON.load(cache).symbolize_keys).to eq user.values
  end

  it 'won\'t write through cache if unicache is not enabled for this key' do
    User.instance_exec { unicache :id, enabled: false }
    user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                       company_name: 'EMC', department: 'Mozy', employee_id: 23456
    cache = memcache.get("id:#{user.id}")
    expect(cache).to be_nil
  end

  it 'won\'t write through cache if unicache is not enabled' do
    User.instance_exec { unicache :id, enabled: true }
    user = User.without_unicache do
             User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
           end
    cache = memcache.get("id:#{user.id}")
    expect(cache).to be_nil

    Sequel::Unicache.disable
    user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                       company_name: 'EMC', department: 'Mozy', employee_id: 23456
    cache = memcache.get("id:#{user.id}")
    expect(cache).to be_nil
  end

  it 'won\'t write through cache if condition is not permitted' do
    User.instance_exec { unicache :id, if: ->(model, _) { model.company_name == 'EMC' } }
    user1 = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                        company_name: 'EMC', department: 'Mozy', employee_id: 23456
    user2 = User.create username: 'bachue@vmware.mozy.com', password: 'bachue',
                        company_name: 'VMware', department: 'Mozy', employee_id: 23456

    cache = memcache.get("id:#{user1.id}")
    expect(cache).not_to be_nil
    expect(Marshal.load(cache)).to eq user1.values

    cache = memcache.get("id:#{user2.id}")
    expect(cache).to be_nil
  end

  it 'can set expiration time as you wish' do
    User.instance_exec { unicache :id, ttl: 1 }
    user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                       company_name: 'EMC', department: 'Mozy', employee_id: 23456
    cache = memcache.get("id:#{user.id}")
    expect(cache).not_to be_nil
    sleep 1
    cache = memcache.get("id:#{user.id}")
    expect(cache).to be_nil
  end

  it 'won\'t write through cache until the transaction is committed' do
    user = nil
    User.db.transaction auto_savepoint: :always do
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end
    cache = memcache.get("id:#{user.id}")
    expect(cache).not_to be_nil
    expect(Marshal.load(cache)).to eq user.values
  end

  it 'can write through for all unicache keys'
end
