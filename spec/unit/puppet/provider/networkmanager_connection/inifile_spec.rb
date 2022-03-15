# frozen_string_literal: true

require 'spec_helper'

describe Puppet::Type.type(:networkmanager_connection).provider(:inifile) do
  include PuppetlabsSpec::Files

  let(:name) do
    'Wired Connection 1'
  end
  let(:parameters) do
    {
      name: name,
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
        uuid: 'c2fec85c-d2ba-4db9-bed3-cf0471623963',
        ensure: :active,
        settings: nmconn_settings,
        purge_settings: true,
        path: nmconn_file
      }
    end

    it 'uses nmcli to activate the connection' do
      allow(provider).to receive(:settings).and_return({})

      expect(provider).to receive(:nmcli).with(:connection, :show, '--active', :uuid, 'c2fec85c-d2ba-4db9-bed3-cf0471623963').and_return('yes')

      expect(provider.active?).to eq(true)

      expect(resource).to receive(:[]).with(:uuid).and_return(nil)
      expect(resource).to receive(:[]).with(:name).and_return(name)
      expect(provider).to receive(:nmcli).with(:connection, :show, '--active', :id, 'Wired Connection 1').and_return('yes')

      expect(provider.active?).to eq(true)
    end

    it 'writes the default connection correctly' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, 'c2fec85c-d2ba-4db9-bed3-cf0471623963')

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
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, 'c2fec85c-d2ba-4db9-bed3-cf0471623963')

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

    it 'acts idempotently' do
      expect(provider).to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).to receive(:nmcli).with(:connection, :up, :uuid, 'c2fec85c-d2ba-4db9-bed3-cf0471623963')

      provider.activate

      expect(provider).not_to receive(:nmcli).with(:connection, :load, nmconn_file)
      expect(provider).not_to receive(:nmcli).with(:connection, :up, :uuid, 'c2fec85c-d2ba-4db9-bed3-cf0471623963')

      provider.activate
    end
  end
end
