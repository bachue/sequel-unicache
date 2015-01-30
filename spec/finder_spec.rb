describe Sequel::Unicache::Finder do
  let!(:user_id) { User.first.id }

  before :each do
    Sequel::Unicache.configure cache: memcache
  end

  context 'simple pk' do
    it 'should cache' do
      user = User[user_id]
      cache = memcache.get "id:#{user.id}"
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq user.values
    end
  end
end
