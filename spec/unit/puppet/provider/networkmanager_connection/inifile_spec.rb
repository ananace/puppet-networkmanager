# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_connection).provider(:inifile) do
  include PuppetlabsSpec::Files

  let(:name) { 'Wired Connection 1' }
  let(:uuid) { 'c2fec85c-d2ba-4db9-bed3-cf0471623963' }
  let(:parameters) do
    {
      name: name,
      uuid: uuid,
    }
  end

  let(:resource) { Puppet::Type::Networkmanager_connection.new(parameters) }
  let(:provider) { described_class.new(resource) }

  context 'with example configuration' do
    let(:nmconn_file) { tmpfilename('nm-connection') }
    let(:nmconn_settings) do
      {
        'connection/interface-name' => 'eno1',
        'ethernet/mac-address' => '00:01:02:03:04:05',
      }
    end
    let(:parameters) do
      {
        name: name,
        uuid: uuid,
        ensure: :active,
        settings: nmconn_settings,
        purge_settings: true,
        path: nmconn_file
      }
    end

    it 'discovers connections correctly' do
      File.write nmconn_file, <<~DOC
      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      DOC

      allow(Dir).to receive(:[]).with('/etc/NetworkManager/system-connections/*.nmconnection').and_return([nmconn_file])
      exec_mock = double()
      allow(provider.class).to receive(:nmcli_safe).with('--terse', '--fields', 'name,uuid,filename', :connection, :show).and_return(exec_mock)
      allow(exec_mock).to receive(:exitstatus).and_return(0)
      allow(exec_mock).to receive(:stdout).and_return <<~STDOUT
      Wired connection:90565afc-51e5-39bc-bcc4-8b9a0213e4aa:/etc/NetworkManager/system-connections/Wired connection.nmconnection
      tun0:4f9fc571-ebb3-4bc8-a9dd-c408fd050b28:/run/NetworkManager/system-connections/tun0.nmconnection
      lo:bcd1855a-29d0-4698-b816-e226cb1b4c42:/run/NetworkManager/system-connections/lo.nmconnection
      Bond connection 1\\:1:499673a4-4f5f-465c-bdbd-798e6c368692:/etc/NetworkManager/system-connections/Bond connection 1.nmconnection
      Bluetooth Network:8526bd22-dfb3-4bef-8de1-319e3e130540:/run/NetworkManager/system-connections/Bluetooth Network.nmconnection
      STDOUT

      instances = provider.class.instances
      expect(instances.size).to eq(3)

      expect(instances[0].instance_variable_get(:@property_hash)).to eq(name: 'Wired connection', uuid: '90565afc-51e5-39bc-bcc4-8b9a0213e4aa', path: '/etc/NetworkManager/system-connections/Wired connection.nmconnection')
      expect(instances[1].instance_variable_get(:@property_hash)).to eq(name: 'Bond connection 1:1', uuid: '499673a4-4f5f-465c-bdbd-798e6c368692', path: '/etc/NetworkManager/system-connections/Bond connection 1.nmconnection')
      expect(instances[2].instance_variable_get(:@property_hash)).to eq(name: 'Wired Connection 1', uuid: 'c2fec85c-d2ba-4db9-bed3-cf0471623963', path: nmconn_file)
    end

    it 'uses nmcli to activate the connection' do
      allow(provider).to receive(:settings).and_return({})

      expect(provider).to receive(:nmcli).with(:connection, :show, '--active', :uuid, uuid).and_return('yes')

      expect(provider.active?).to eq(true)

      expect(resource).to receive(:[]).with(:uuid).and_return(nil)
      expect(resource).to receive(:[]).with(:name).and_return(name)
      expect(provider).to receive(:nmcli).with(:connection, :show, '--active', :id, 'Wired Connection 1').and_return('yes')

      expect(provider.active?).to eq(true)
    end

    it 'writes the default connection correctly' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      provider.activate

      data = File.read nmconn_file
      expect(data).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      DOC
    end

    it 'writes a complete connection' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      catalog = instance_double('catalog')
      expect(catalog).to receive(:resources).and_return([])
      expect(resource).to receive(:catalog).and_return(catalog)

      provider.settings = nmconn_settings
      provider.flush

      data = File.read nmconn_file
      expect(data).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      interface-name=eno1

      [ethernet]
      mac-address=00:01:02:03:04:05
      DOC
    end

    it 'handles existing connections' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      catalog = instance_double('catalog')
      expect(catalog).to receive(:resources).and_return([])
      expect(resource).to receive(:catalog).and_return(catalog)

      File.write nmconn_file, <<~DOC
      [connection]
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      id=Wired Connection 1
      interface-name=eno1
      permissions=
      [ipv4]
      may-fail=false
      address1=192.168.0.1
      [ethernet]
      auto-negotiate=true
      DOC

      provider.settings = nmconn_settings
      provider.flush

      data = File.read nmconn_file
      expect(data).to eq <<~DOC
      # Managed by Puppet

      [connection]
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      id=Wired Connection 1
      interface-name=eno1

      [ethernet]
      mac-address=00:01:02:03:04:05
      DOC
    end

    it 'acts idempotently' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).not_to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      expect(provider.exists?).to eq false
      provider.create

      execresult = double
      allow(execresult).to receive(:exitstatus).and_return(0)

      allow(provider).to receive(:nmcli_safe).with(:connection, :show, :uuid, uuid).and_return(execresult)
      expect(provider).not_to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).not_to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      expect(provider.exists?).to eq true
      expect(provider.loaded?).to eq true

      provider.create
    end

    it 'reloads if necessary' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      expect(provider.exists?).to eq false
      provider.activate

      provider.instance_variable_set :@connection_loaded, false
      provider.instance_variable_set :@activated_this_session, false

      execresult = double
      allow(execresult).to receive(:exitstatus).and_return(10)

      allow(provider).to receive(:nmcli_safe).with(:connection, :show, :uuid, uuid).and_return(execresult)

      expect(provider.exists?).to eq true
      expect(provider.loaded?).to eq false

      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      provider.activate

      expect(provider.exists?).to eq true
      expect(provider.loaded?).to eq true
    end
  end

  context 'in a complex catalog' do
    let(:nmconn_file) { tmpfilename('nm-connection') }
    let(:catalog) do
      catalog = Puppet::Resource::Catalog.new

      catalog.add_resource(Puppet::Type::Networkmanager_connection.new(
        name: name,
        uuid: uuid,
        settings: {
          'connection/type' => 'ethernet',
          'ethernet/auto-negotiate' => true,
          'ipv4/may-fail' => true,
          'ipv6/may-fail' => true,
        },
        purge_settings: true,
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ethernet/mac-address',
        value: '48:0F:CF:5F:D2:6D',
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ipv4/method',
        value: 'auto',
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ipv4/dns-search',
        value: 'example.com',
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ipv6/method',
        value: 'manual',
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ipv6/dns-search',
        value: 'example.com',
        path: nmconn_file,
      ))
      catalog.add_resource(Puppet::Type::Networkmanager_connection_setting.new(
        name: 'Wired Connection 1/ipv6/address1',
        value: 'fe80::c275:d67f:fc22:2b22/64',
        path: nmconn_file,
      ))

      catalog.finalize

      catalog
    end

    before(:each) do
      allow(Puppet::Util::Storage).to receive(:store)

      expect_any_instance_of(described_class).to receive(:nmcli).with(:connection, :load, nmconn_file) # rubocop:disable RSpec/AnyInstance

      execresult = double
      allow(execresult).to receive(:exitstatus).and_return(0)

      allow_any_instance_of(described_class).to receive(:nmcli_safe).with(:connection, :show, :uuid, uuid).and_return(execresult) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:nmcli).with(:connection, :show, '--active', :uuid, uuid).and_return(false) # rubocop:disable RSpec/AnyInstance
    end

    it 'generates a valid connection with no prior art' do
      expect(File.exist?(nmconn_file)).to eq false

      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
      # Managed by Puppet

      [ethernet]
      mac-address=48:0F:CF:5F:D2:6D
      auto-negotiate=true

      [ipv4]
      method=auto
      dns-search=example.com
      may-fail=true

      [ipv6]
      method=manual
      dns-search=example.com
      address1=fe80::c275:d67f:fc22:2b22/64
      may-fail=true

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet
      DOC
    end

    it 'expands on existing data' do
      File.write nmconn_file, <<~DOC
      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet
      [ipv4]
      method=auto
      [ipv6]
      method=auto
      DOC

      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet

      [ipv4]
      method=auto
      dns-search=example.com
      may-fail=true

      [ipv6]
      method=manual
      dns-search=example.com
      address1=fe80::c275:d67f:fc22:2b22/64
      may-fail=true

      [ethernet]
      mac-address=48:0F:CF:5F:D2:6D
      auto-negotiate=true
      DOC
    end

    it 'purges unwanted configuration' do
      File.write nmconn_file, <<~DOC
      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet
      permissions=

      [ethernet]
      auto-negotiate=true
      mac-address=48:0F:CF:5F:D2:6D
      mac-address-blacklist=

      [ipv4]
      dns-search=old.example.com;
      method=auto

      [ipv6]
      addr-gen-mode=stable-privacy
      address1=200:120:142:f::19/64
      dns-search=
      method=manual

      [proxy]
      DOC

      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet

      [ethernet]
      auto-negotiate=true
      mac-address=48:0F:CF:5F:D2:6D

      [ipv4]
      dns-search=example.com
      method=auto
      may-fail=true

      [ipv6]
      address1=fe80::c275:d67f:fc22:2b22/64
      dns-search=example.com
      method=manual
      may-fail=true
      DOC
    end
  end
end
