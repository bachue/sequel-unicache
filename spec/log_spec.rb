require 'spec_helper'

describe Sequel::Unicache::Logger do
  let!(:logger) { Logger.new STDOUT }
  let!(:user_id) { User.first.id }
  before :each do
    Sequel::Unicache.configure cache: memcache, logger: logger
  end

  context 'read through' do
    it 'should log down and ignore exception if failed to serialize' do
      User.instance_exec { unicache :id, serialize: ->(values, _) { raise 'test' } }
      expect(logger).to receive(:error).at_least(:once)
      user = User[user_id]
      cache = memcache.get "id:#{user.id}"
      expect(cache).to be_nil
    end
  end

  context 'expire' do
    it 'should log down, ignore exception when failed to expire during model destroy' do
      user = User[user_id]
      cache = memcache.get "id:#{user.id}"
      expect(cache).not_to be_nil
      User.instance_exec { unicache :id, key: ->(values, _) { raise 'test' } }
      expect(logger).to receive(:fatal).at_least(:once)
      user.destroy
    end
  end
end
