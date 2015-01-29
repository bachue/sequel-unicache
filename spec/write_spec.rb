require 'spec_helper'

describe Sequel::Unicache::Write do
  let!(:user_id) { User.first.id }

  before :each do
    Sequel::Unicache.configure cache: memcache
  end

  context 'read through' do
    it 'should read through cache into memcache' do
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end

    it 'should serialize model into specified format' do
      User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_json } }
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(JSON.load(cache).symbolize_keys).to eq user.values
    end

    it 'should not read through cache if unicache is not enabled for this key' do
      User.instance_exec { unicache :id, enabled: false }
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should not read through cache if unicache is not enabled' do
      User.instance_exec { unicache :id, enabled: true }
      user = User.without_unicache do
               User[user_id]
             end
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil

      Sequel::Unicache.disable
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should not write through cache if condition is not permitted' do
      User.instance_exec { unicache :id, if: ->(model, _) { model.company_name != 'EMC' } }
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should set expiration time as you wish' do
      User.instance_exec { unicache :id, ttl: 1 }
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      sleep 1
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end
  end

  context 'expire when update' do
    let(:user) { User[user_id] }

    it 'should expire cache' do
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      user.set(company_name: 'EMC').save
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
      user = User[user_id]
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end

    it 'should not expire cache until transaction is permitted' do
      User.db.transaction auto_savepoint: true do
        user.set(company_name: 'EMC').save
        cache = memcache.get("id:#{user.id}")
        expect(cache).not_to be_nil
      end
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should still expire cache even if unicache is not enabled for that key' do
      User.disable_unicache_for(:id)
      user.set(company_name: 'EMC').save
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should still expire cache even if unicache is not enabled' do
      Sequel::Unicache.disable
      user.set(company_name: 'EMC').save
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should still expire all cache even if model is not completed' do
      User.instance_exec { unicache :username, key: ->(values, _) { "username:#{values[:username]}" } }
      user = User[user_id]
      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).not_to be_nil
      user = User.select(:id, :company_name)[user_id]
      user.set(company_name: 'VMware').save
      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).to be_nil
    end

    it 'should expire obsolate cache if value of the unicache is changed' do
      User.instance_exec { unicache :username }
      user = User[user_id]
      User.db.transaction(auto_savepoint: true) do
        user.set(username: 'bachue@emc.com').save
        user.set(username: 'bachue@vmware.com', company_name: 'VMware').save
      end
      cache = memcache.get("username:bachue@gmail.com")
      expect(cache).to be_nil
    end
  end

  context 'expire when delete' do
    let(:user) { User[user_id] }

    it 'should expire cache' do
      cache = memcache.get("id:#{user.id}")
      expect(cache).not_to be_nil
      user.destroy
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should not expire cache until transaction is permitted' do
      User.db.transaction auto_savepoint: true do
        user.destroy
        cache = memcache.get("id:#{user.id}")
        expect(cache).not_to be_nil
      end
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should still expire cache even if unicache is not enabled for that key' do
      User.disable_unicache_for(:id)
      user.destroy
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end

    it 'should still expire cache even if unicache is not enabled' do
      Sequel::Unicache.disable
      user.destroy
      cache = memcache.get("id:#{user.id}")
      expect(cache).to be_nil
    end
  end
end
