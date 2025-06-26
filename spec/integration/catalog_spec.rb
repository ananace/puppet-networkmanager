# frozen_string_literal: true

require 'spec_helper'

describe 'NetworkManager integration test' do
  let(:fixture) { Psych.load(File.read(File.join('spec', 'fixtures', 'foreman_interfaces', 'realworld.yml'))) }
  let(:uuid) { 'UUID-PLACEHOLDER' }

  let(:facts) { fixture['facts'] }
  let(:node_params) do
    {
      'foreman_interfaces' => fixture['foreman_interfaces'],
      'domainname' => 'example.com'
    }
  end
  let(:basepath) { Dir.mktmpdir('nm-connection') }
  let(:catalogue) do
    Puppet::Resource::Catalog.new.tap do |cat|
      cat.host_config = false

      fixture['resources'].each do |type, resources|
        resources.each do |name, values|
          pathname = File.join(basepath, "#{name.split('/').first}.nmconnection")
          instance = Puppet::Type.type(type.downcase.to_sym).new(path: pathname, **values)

          cat.add_resource(instance)
        end
      end
    end
  end

  before(:each) do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:inifile)).to receive(:uuid).and_return(uuid)

    allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:inifile)).to receive(:nmcli)
    allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:checkpointed_dbussend)).to receive(:dbus_call).and_return('"placeholder"')
    allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:checkpointed_dbussend)).to receive(:verify_connection)
    # rubocop:enable RSpec/AnyInstance
  end

  after(:each) do
    Dir.rmdir(basepath)
  end

  context 'when applied correctly' do
    it do
      catalogue.apply

      expect(Dir["#{basepath}/*"].count).to eq(2)

      path1 = File.join(basepath, 'enp2s0f0.nmconnection')
      path2 = File.join(basepath, 'enp2s0f0.1.nmconnection')
      conn1 = File.read(path1)
      conn2 = File.read(path2)

      expect(conn1).to eq(
        <<~CONN1,
        # Managed by Puppet

        [connection]
        interface-name=enp2s0f0
        autoconnect=true
        type=ethernet
        id=enp2s0f0
        uuid=UUID-PLACEHOLDER

        [ethernet]
        mac-address=3C:4A:92:F6:CE:10
        mtu=1500

        [ipv4]
        method=manual
        address1=10.216.252.20/24,10.216.252.1
        may-fail=false
        dns=10.216.252.21;10.216.252.23
        dns-search=example.com
        route-metric=50
        never-default=false

        [ipv6]
        method=manual
        address1=fcdd:ef55:17:f080::20/64,fcdd:ef55:17:f080::1
        may-fail=false
        dns=fcdd:ef55:17:f080::17;fcdd:ef55:17:f080::19
        dns-search=example.com
        route-metric=50
        never-default=false
        CONN1
      )

      expect(conn2).to eq(
        <<~CONN2,
        # Managed by Puppet

        [connection]
        interface-name=enp2s0f0.1
        autoconnect=true
        type=vlan
        id=enp2s0f0.1
        uuid=UUID-PLACEHOLDER

        [vlan]
        id=1
        interface-name=enp2s0f0.1

        [ethernet]
        mac-address=3C:4A:92:F6:CE:10
        mtu=1500

        [ipv4]
        method=manual
        address1=172.31.0.107/24,172.31.0.1
        may-fail=false
        dns=172.31.0.127;172.31.0.129
        dns-search=example.com
        route-metric=100
        never-default=true

        [ipv6]
        method=ignore
        may-fail=true
        route-metric=100
        never-default=true
        CONN2
      )

    ensure
      File.delete path1
      File.delete path2
    end
  end

  context 'when applied incorrectly' do
    it do
      before = <<~CONN1
        # Managed by Puppet

        [connection]
        interface-name=enp2s0f0
        autoconnect=true
        type=ethernet
        id=enp2s0f0
        uuid=UUID-PLACEHOLDER

        [ethernet]
        mac-address=3C:4A:92:F6:CE:10
        mtu=1500

        [ipv4]
        method=manual
        address1=10.216.252.10/24,10.216.252.1
        may-fail=false
        dns=10.216.252.21;10.216.252.23
        dns-search=example.com
        route-metric=50
        never-default=false

        [ipv6]
        method=manual
        address1=fcdd:ef55:17:f080::20/64,fcdd:ef55:17:f080::1
        may-fail=false
        dns=fcdd:ef55:17:f080::17;fcdd:ef55:17:f080::19
        dns-search=example.com
        route-metric=50
        never-default=false
      CONN1

      path1 = File.join(basepath, 'enp2s0f0.nmconnection')
      path2 = File.join(basepath, 'enp2s0f0.1.nmconnection')

      File.write path1, before
      conn1 = File.read(path1)
      expect(conn1).to eq(before)

      allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:inifile)).to receive(:nmcli).with(:connection, :load, path1).and_raise(StandardError, 'Fake load error') # rubocop:disable RSpec/AnyInstance

      catalogue.apply

      expect(Dir["#{basepath}/*"].count).to eq(2)

      conn1 = File.read(path1)
      conn2 = File.read(path2)

      expect(conn1).to eq(before)
      expect(conn2).to eq(
        <<~CONN2,
        # Managed by Puppet

        [connection]
        interface-name=enp2s0f0.1
        autoconnect=true
        type=vlan
        id=enp2s0f0.1
        uuid=UUID-PLACEHOLDER

        [vlan]
        id=1
        interface-name=enp2s0f0.1

        [ethernet]
        mac-address=3C:4A:92:F6:CE:10
        mtu=1500

        [ipv4]
        method=manual
        address1=172.31.0.107/24,172.31.0.1
        may-fail=false
        dns=172.31.0.127;172.31.0.129
        dns-search=example.com
        route-metric=100
        never-default=true

        [ipv6]
        method=ignore
        may-fail=true
        route-metric=100
        never-default=true
        CONN2
      )

    ensure
      File.delete path1
      File.delete path2
    end
  end

  context 'when activation results in broken link' do
    it do
      before = <<~CONN1
        # Managed by Puppet

        [connection]
        interface-name=enp2s0f0
        autoconnect=true
        type=ethernet
        id=enp2s0f0
        uuid=UUID-PLACEHOLDER

        [ethernet]
        mac-address=3C:4A:92:F6:CE:10
        mtu=1500

        [ipv4]
        method=manual
        address1=10.216.252.10/24,10.216.252.1
        may-fail=false
        dns=10.216.252.21;10.216.252.23
        dns-search=example.com
        route-metric=50
        never-default=false

        [ipv6]
        method=manual
        address1=fcdd:ef55:17:f080::20/64,fcdd:ef55:17:f080::1
        may-fail=false
        dns=fcdd:ef55:17:f080::17;fcdd:ef55:17:f080::19
        dns-search=example.com
        route-metric=50
        never-default=false
      CONN1
      path1 = File.join(basepath, 'enp2s0f0.nmconnection')
      File.write path1, before

      allow_any_instance_of(Puppet::Type.type(:networkmanager_connection).provider(:checkpointed_dbussend)).to receive(:verify_connection).and_raise(StandardError, 'Fake connection error') # rubocop:disable RSpec/AnyInstance

      catalogue.apply

      conn1 = File.read(path1)

      # Ensure connection remains as before attempt
      expect(conn1).to eq(before)
      expect(Dir["#{basepath}/*"].count).to eq(1)
    ensure
      File.delete path1
    end
  end
end
