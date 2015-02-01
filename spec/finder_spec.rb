describe Sequel::Unicache::Finder do
  let!(:user_id) { User.first.id }

  before :each do
    Sequel::Unicache.configure cache: memcache
  end

  context '.[]' do
    context 'simple pk' do
      it 'should cache' do
        user = User[user_id]
        cache = memcache.get "User:id:#{user.id}"
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_yaml }, deserialize: ->(values, _) { YAML.load values } }
        expect(User[10]).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC', employee_id: 1000 }
        memcache.set 'User:id:10', values.to_yaml
        user = User[10]
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end

    context 'single unicache key' do
      before :each do
        User.instance_exec { unicache :username }
      end

      it 'should cache' do
        user = User[username: 'bachue@gmail.com']
        cache = memcache.get 'User:username:bachue@gmail.com'
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        expect(User[username: 'bachue@emc.com']).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC', employee_id: 1000 }
        memcache.set 'User:username:bachue@emc.com', Marshal.dump(values)
        user = User[username: 'bachue@emc.com']
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end

    context 'complexed unicache key' do
      before :each do
        User.instance_exec { unicache :company_name, :department, :employee_id }
      end

      it 'should cache' do
        user = User[company_name: 'EMC', department: 'Mozy', employee_id: 12345]
        cache = memcache.get 'User:company_name:EMC:department:Mozy:employee_id:12345'
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        expect(User[company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000]).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000 }
        memcache.set 'User:company_name:EMC:department:DPC\:Mozy:employee_id:1000', Marshal.dump(values)
        user = User[company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000]
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end

    context 'negative cases' do
      it 'should only read-through from simple dataset' do
        User[user_id] # cache primary key
        expect(User.where(department: 'DPC')[user_id]).to be_nil
        expect(User.offset(1)[user_id]).to be_nil
      end

      it 'should not read-through from joined dataset' do
        user = User[1] # cache primary key
        ds = User.inner_join :users, {id: :manager_id}, table_alias: 'managers'
        expect(ds[1].values).not_to eq user.values
      end
    end
  end

  context '.find' do
    context 'simple pk' do
      it 'should cache' do
        user = User.find user_id
        cache = memcache.get "User:id:#{user.id}"
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        User.instance_exec { unicache :id, serialize: ->(values, _) { values.to_yaml }, deserialize: ->(values, _) { YAML.load values } }
        expect(User.find 10).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC', employee_id: 1000 }
        memcache.set 'User:id:10', values.to_yaml
        user = User.find 10
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end

    context 'single unicache key' do
      before :each do
        User.instance_exec { unicache :username }
      end

      it 'should cache' do
        user = User.find username: 'bachue@gmail.com'
        cache = memcache.get "User:username:bachue@gmail.com"
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        User.instance_exec { unicache :username, serialize: ->(values, _) { values.to_yaml }, deserialize: ->(values, _) { YAML.load values } }
        expect(User.find(username: 'bachue@emc.com')).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC', employee_id: 1000 }
        memcache.set 'User:username:bachue@emc.com', values.to_yaml
        user = User.find username: 'bachue@emc.com'
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end

    context 'complexed unicache key' do
      before :each do
        User.instance_exec { unicache :company_name, :department, :employee_id }
      end

      it 'should cache' do
        user = User.find company_name: 'EMC', department: 'Mozy', employee_id: 12345
        cache = memcache.get 'User:company_name:EMC:department:Mozy:employee_id:12345'
        expect(cache).not_to be_nil
        expect(Marshal.load(cache)).to eq user.values
      end

      it 'should get model from cache' do
        expect(User.find company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000).to be_nil
        values = { id: 10, username: 'bachue@emc.com', password: '123456', company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000 }
        memcache.set 'User:company_name:EMC:department:DPC\:Mozy:employee_id:1000', Marshal.dump(values)
        user = User.find company_name: 'EMC', department: 'DPC:Mozy', employee_id: 1000
        expect(user).not_to be_nil
        expect(user.values).to eq values
      end
    end
  end

  context 'association' do
    let!(:user) { User.first }

    it 'should cache associated object' do
      manager = user.manager
      cache = memcache.get "User:id:#{manager.id}"
      expect(cache).not_to be_nil
      expect(Marshal.load(cache)).to eq manager.values
    end

    it 'should get model from cache' do
      expect(user.manager.manager).to be_nil
      values = { id: 10, username: 'tim@emc.com', password: 'abcdef', company_name: 'EMC', department: 'DPC:Mozy', employee_id: 100 }
      memcache.set "User:id:10", Marshal.dump(values)
      user.manager.set manager_id: 10
      manager = user.manager.manager
      expect(manager).not_to be_nil
      expect(manager.values).to eq values
    end
  end
end
