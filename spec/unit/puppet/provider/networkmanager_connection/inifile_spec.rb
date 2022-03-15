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
      # provider.activate # called implicitly

      data = File.read nmconn_file
      expect(data).to eq <<~DOC
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
      # provider.activate # called implicitly

      data = File.read nmconn_file
      expect(data).to eq <<~DOC
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
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      expect(provider.exists?).to eq false
      provider.activate

      expect(provider).not_to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).not_to receive(:nmcli).with(:connection, :up, :uuid, uuid)

      expect(provider.exists?).to eq true
      provider.activate
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

      catalog
    end

    before(:each) do
      allow(Puppet::Util::Storage).to receive(:store)

      expect_any_instance_of(described_class).to receive(:nmcli).with(:connection, :load, nmconn_file) # rubocop:disable RSpec/AnyInstance
    end

    it 'generates a valid connection with no prior art' do
      expect(File.exist?(nmconn_file)).to eq false

      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
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
