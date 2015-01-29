require 'spec_helper'

describe Sequel::Unicache::Write do
  before :each do
    Sequel::Unicache.configure cache: memcache, enabled: true, ttl: 120
  end

  context 'create' do
    it 'should write through cache into memcache' do
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end

    it 'should serialize model into specified format' do
      User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_json } }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(JSON.load(cache).symbolize_keys).to eq user.values
    end

    it 'should not write through cache if unicache is not enabled for this key' do
      User.instance_exec { unicache :id, enabled: false }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should not write through cache if unicache is not enabled' do
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

    it 'should not write through cache if condition is not permitted' do
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

    it 'should set expiration time as you wish' do
      User.instance_exec { unicache :id, ttl: 1 }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      sleep 1
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should not write through cache until the transaction is committed' do
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

    it 'should write through for all unicache keys' do
      User.instance_exec { unicache :username, serialize: ->(values, _) { values.to_yaml } }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values

      cache = memcache.get("username:bachue@emc.mozy.com")
      expect(cache).not_to be_nil
      expect(YAML.load(cache)).to eq user.values
    end

    it 'should work even if the key is very long' do
      User.instance_exec { unicache :username }
      username = 'bachue' * 1000 + '@emc.mozy.com'
      user = User.create username: username, password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456

      cache = memcache.get("username:#{username}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end
  end

  context 'update' do
    it 'should update cache in specified format' do
      User.instance_exec { unicache :username, serialize: ->(values, _) { values.to_yaml } }
      user = User.first.set_all(company_name: 'VMware', employee_id: 12346, created_at: Time.now).save

      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values

      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).not_to be_nil
      expect(YAML.load(cache)).to eq user.values
    end

    it 'should not update cache until transaction is permitted' do
      user = nil
      User.db.transaction auto_savepoint: :always do
        user = User.first.set_all(company_name: 'VMware', employee_id: 12346, created_at: Time.now).save
        cache = memcache.get("id:#{user.id}")
        expect(cache).to be_nil
      end
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end

    it 'should not update cache if unicache is not enabled for this key' do
      User.instance_exec { unicache :username, enabled: false }
      user = User.first.set_all(company_name: 'VMware', employee_id: 12346, created_at: Time.now).save

      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values

      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).to be_nil
    end

    it 'should not update cache if unicache is not enabled' do
      User.instance_exec { unicache :username, enabled: false }
      Sequel::Unicache.disable
      user = User.first.set_all(company_name: 'VMware', employee_id: 12346, created_at: Time.now).save

      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil

      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).to be_nil
    end

    it 'should not update cache if condition is not permitted' do
      User.instance_exec { unicache :username, if: ->(model, _) { model.company_name == 'EMC' } }
      user = User.first.set_all(company_name: 'VMware', employee_id: 12346, created_at: Time.now).save

      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values

      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).to be_nil
    end

    it 'should expire cache if condition is not permitted' do
      User.instance_exec { unicache :id, if: ->(model, _) { model.company_name == 'EMC' } }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil

      user.set_all(company_name: 'VMware').save
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should always expire cache if write through is disabled' do
      User.instance_exec { unicache :id, if: ->(model, _) { model.company_name == 'EMC' } }
      user = User.create username: 'bachue@emc.mozy.com', password: 'bachue',
                         company_name: 'EMC', department: 'Mozy', employee_id: 23456
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil

      User.unicache_for(:id).write_through = false
      user.set_all(company_name: 'VMware').save
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end
  end

  context 'delete' do
    it 'should expire cache'
    it 'should not expire cache until transaction is permitted'
    it 'should still expire cache even if unicache is not enabled for that key'
    it 'should not expire cache if unicache is not enabled'
  end
end
