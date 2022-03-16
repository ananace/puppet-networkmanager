require 'spec_helper'
require 'puppet'

describe Puppet::Type.type(:networkmanager_connection) do
  include PuppetlabsSpec::Files

  let(:resource) do
    described_class.new(
      name: 'em1',
    )
  end

  context 'resource defaults' do
    it { expect(resource[:ensure]).to eq :present }
  end

  it 'verify resource[:path] is absolute filepath' do
    expect { resource[:path] = 'relative/file' }.to raise_error(Puppet::Error, %r{File paths must be fully qualified, not 'relative/file'})
  end

  context 'in a catalog' do
    let(:name) { 'Wired Connection 1' }
    let(:uuid) { 'c2fec85c-d2ba-4db9-bed3-cf0471623963' }
    let(:nmconn_file) { tmpfilename('nm-connection') }
    let(:resource) do
      described_class.new(
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
      )
    end
    let(:catalog) do
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource(resource)

      catalog
    end

    it 'queues up purges for unwanted resources' do
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

      conn = resource.provider.send :connection

      expect(conn).to receive(:remove_setting).with('connection', 'permissions')
      expect(conn).to receive(:remove_setting).with('ethernet', 'mac-address')
      expect(conn).to receive(:remove_setting).with('ethernet', 'mac-address-blacklist')
      expect(conn).to receive(:remove_setting).with('ipv4', 'dns-search')
      expect(conn).to receive(:remove_setting).with('ipv4', 'method')
      expect(conn).to receive(:remove_setting).with('ipv6', 'addr-gen-mode')
      expect(conn).to receive(:remove_setting).with('ipv6', 'address1')
      expect(conn).to receive(:remove_setting).with('ipv6', 'dns-search')
      expect(conn).to receive(:remove_setting).with('ipv6', 'method')

      expect(catalog.resources).to include(resource)
      res = resource.generate

      res.each { |r| r.provider.destroy }
    end

    it 'flushes purged changes correctly' do
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

      expect(resource.provider).to receive(:nmcli).with(:connection, :load, nmconn_file)

      allow(Puppet::Util::Storage).to receive(:store)
      expect(catalog.resources).to include(resource)
      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet

      [ethernet]
      auto-negotiate=true

      [ipv4]
      may-fail=true

      [ipv6]
      may-fail=true
      DOC
    end

    it 'fixes formatting without reloading' do
      File.write nmconn_file, <<~DOC
      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet
      [ethernet]
      auto-negotiate=true
      [ipv4]
      may-fail=true
      [ipv6]
      may-fail=true
      DOC

      expect(resource.provider).not_to receive(:nmcli).with(:connection, :load, nmconn_file)

      allow(Puppet::Util::Storage).to receive(:store)
      expect(catalog.resources).to include(resource)
      catalog.apply

      expect(File.read(nmconn_file)).to eq <<~DOC
      # Managed by Puppet

      [connection]
      id=Wired Connection 1
      uuid=c2fec85c-d2ba-4db9-bed3-cf0471623963
      type=ethernet

      [ethernet]
      auto-negotiate=true

      [ipv4]
      may-fail=true

      [ipv6]
      may-fail=true
      DOC
    end
  end
end
