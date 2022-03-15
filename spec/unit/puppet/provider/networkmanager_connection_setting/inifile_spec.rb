require 'spec_helper'

describe Puppet::Type.type(:networkmanager_connection_setting).provider(:inifile) do
  include PuppetlabsSpec::Files

  describe 'simple setting usage' do
    let(:name) { 'em1/connection/type' }
    let(:parameters) do
      {
        name: name,
        value: 'ethernet',
      }
    end

    let(:resource) { Puppet::Type::Networkmanager_connection_setting.new(parameters) }
    let(:provider) { described_class.new(resource) }

    it 'discovers setting information' do
      expect(provider.connection_name).to eq 'em1'
      expect(provider.section).to eq 'connection'
      expect(provider.setting).to eq 'type'
      expect(provider.file_path).to eq '/etc/NetworkManager/system-connections/em1.nmconnection'
      expect(provider.generate_full_name).to eq 'em1/connection/type'
    end

    context 'with existing connection' do
      let(:nmconn_file) { tmpfilename('nm-connection') }

      before(:each) { allow(provider).to receive(:file_path).and_return nmconn_file }

      it 'acts idempotently' do
        content = <<~NMCONN
        [connection]
        id=em1
        type=ethernet
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        expect(provider.send(:connection)).not_to receive(:set_setting)
        expect(provider.send(:connection).send(:ini_file)).not_to receive(:store)

        expect(provider.exists?).to be true
        provider.create
      end

      it 'creates when missing' do
        content = <<~NMCONN
        [connection]
        id=em1
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        expect(provider.send(:connection)).to receive(:set_setting).with('connection', 'type', 'ethernet')
        expect(provider.send(:connection).send(:ini_file)).to receive(:store)

        expect(provider.exists?).to be false
        provider.create
      end

      it 'updates when faulty' do
        content = <<~NMCONN
        [connection]
        id=em1
        type=vlan
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        expect(provider.send(:connection)).to receive(:set_setting).with('connection', 'type', 'ethernet')
        expect(provider.send(:connection).send(:ini_file)).to receive(:store)

        expect(provider.exists?).to be true
        provider.create
      end

      it 'removes when ordered' do
        content = <<~NMCONN
        [connection]
        id=em1
        type=ethernet
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        expect(provider.send(:connection)).not_to receive(:set_setting)
        expect(provider.send(:connection)).to receive(:remove_setting).with('connection', 'type')
        expect(provider.send(:connection).send(:ini_file)).to receive(:store)

        expect(provider.exists?).to be true
        provider.destroy
      end
    end
  end

  describe 'when building a full connection' do
    let(:nmconn_file) { tmpfilename('nm-connection') }

    it 'creates a fully-featured file from nothing' do
      entries = {
        'connection/autoconnect' => true,
        'connection/id' => 'connection',
        'connection/type' => 'ethernet',
        'ipv4/method' => 'manual',
        'ipv4/address1' => '10.0.0.2/8,10.0.0.1',
        'ipv6/method' => 'auto',
      }

      entries.each do |key, value|
        parameters = {
          name: "connection/#{key}",
          value: value,
        }
        provider = described_class.new(Puppet::Type::Networkmanager_connection_setting.new(parameters))
        allow(provider).to receive(:file_path).and_return nmconn_file

        provider.create
      end

      expect(File.read(nmconn_file)).to eq <<~FILE
      [connection]
      autoconnect=true
      id=connection
      type=ethernet

      [ipv4]
      method=manual
      address1=10.0.0.2/8,10.0.0.1

      [ipv6]
      method=auto
      FILE
    end

    it 'correctly inserts missing data' do
      File.open(nmconn_file, 'w') do |f|
        content = <<~FILE
        [connection]
        id=connection
        type=ethernet

        [ipv4]
        method=auto

        [ipv6]
        method=auto
        FILE

        f.write content
      end

      entries = {
        'connection/autoconnect' => true,
        'connection/id' => 'connection',
        'connection/type' => 'ethernet',
        'ipv4/method' => 'manual',
        'ipv4/address1' => '10.0.0.2/8,10.0.0.1',
      }

      entries.each do |key, value|
        parameters = {
          name: "connection/#{key}",
          value: value,
        }
        provider = described_class.new(Puppet::Type::Networkmanager_connection_setting.new(parameters))
        allow(provider).to receive(:file_path).and_return nmconn_file

        provider.create
      end

      expect(File.read(nmconn_file)).to eq <<~FILE
      [connection]
      id=connection
      type=ethernet
      autoconnect=true

      [ipv4]
      method=manual
      address1=10.0.0.2/8,10.0.0.1

      [ipv6]
      method=auto
      FILE
    end
  end

  describe 'when showing diff' do
    let(:name) { 'em1/connection/type' }
    let(:resource) { Puppet::Type::Networkmanager_connection_setting.new(parameters) }

    let(:nmconn_file) { tmpfilename('nm-connection') }

    before(:each) { allow_any_instance_of(described_class).to receive(:file_path).and_return nmconn_file } # rubocop:disable RSpec/AnyInstance

    describe 'gives good creation message' do
      let(:parameters) do
        {
          ensure: :present,
          name: name,
          value: 'ethernet',
        }
      end

      it do
        allow(Puppet::Util::Storage).to receive(:store)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        logs = catalog.apply.report.logs

        expect(logs.first.source).to eq('/Networkmanager_connection_setting[em1/connection/type]/ensure')
        expect(logs.first.message).to eq('created')
      end
    end

    describe 'gives good removal message' do
      let(:parameters) do
        {
          ensure: :absent,
          name: name,
        }
      end

      it do
        content = <<~NMCONN
        [connection]
        id=em1
        type=ethernet
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        allow(Puppet::Util::Storage).to receive(:store)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        logs = catalog.apply.report.logs

        expect(logs.first.source).to eq('/Networkmanager_connection_setting[em1/connection/type]/ensure')
        expect(logs.first.message).to eq('removed')
      end
    end

    describe 'gives good modification message' do
      let(:parameters) do
        {
          ensure: :present,
          name: name,
          value: 'vlan',
        }
      end

      it do
        content = <<~NMCONN
        [connection]
        id=em1
        type=ethernet
        NMCONN
        File.open(nmconn_file, 'w') { |f| f.write(content) }

        allow(Puppet::Util::Storage).to receive(:store)

        Puppet[:show_diff] = true
        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(resource)
        logs = catalog.apply.report.logs

        expect(logs.first.source).to eq('/Networkmanager_connection_setting[em1/connection/type]/value')
        expect(logs.first.message).to eq('value changed ethernet to vlan')
      end
    end
  end
end
