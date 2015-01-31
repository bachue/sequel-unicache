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

    it 'should get model from cache' do
      User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_yaml }, deserialize: ->(values, _) { YAML.load values } }
      expect(User[10]).to be_nil
      memcache.set 'id:10', {id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC', employee_id: 1000}.to_yaml
      user = User[10]
      expect(user).not_to be_nil
      expect(user.username).to eq 'bachue@emc.com'
      expect(user.password).to eq '123456'
      expect(user.company_name).to eq 'EMC'
      expect(user.department).to eq 'DPC'
      expect(user.employee_id).to eq 1000
    end
  end
end
