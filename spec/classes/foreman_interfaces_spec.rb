# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::foreman_interfaces' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end

  context 'With complex.yml fixture' do
    data = Psych.load(File.read(File.join('spec', 'fixtures', 'foreman_interfaces', 'complex.yml')))

    let(:facts) { data['facts'] }
    let(:node_params) do
      {
        'foreman_interfaces' => data['foreman_interfaces'],
        'domainname' => 'example.com'
      }
    end

    it { is_expected.to compile }
    it do
      is_expected.to contain_networkmanager__ethernet('enp5s0f0')
        .with_ensure('present')
        .with_mac('00:11:22:33:44:AA')
        .with_mtu(1500)
        .with_ip4_addresses(['1.2.3.4/8', '1.2.3.5/8'])
        .with_ip4_gateway('1.0.0.1')
        .with_ip4_dns(['1.0.1.1', '1.0.1.2'])
        .with_ip4_dns_search('example.com')
        .with_ip4_method('manual')
        .with_ip6_addresses(nil)
    end
    it do
      is_expected.to contain_networkmanager_connection('bond0')
        .with_ensure('active')
        .with_purge_settings(true)
    end
    it do
      is_expected.to contain_networkmanager_connection('bondslave-bond0-enp5s0f0')
        .with_ensure('present')
        .with_purge_settings(true)
    end
    it do
      is_expected.to contain_networkmanager_connection('bondslave-bond0-enp5s0f1')
        .with_ensure('present')
        .with_purge_settings(true)
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/address1')
        .with_value('1.2.3.4/8,1.0.0.1')
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/address2')
        .with_value('1.2.3.5/8')
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/dns')
        .with_value('1.0.1.1;1.0.1.2')
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/dns-search')
        .with_value('example.com')
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/may-fail')
        .with_value(false)
    end
    it do
      is_expected.to contain_networkmanager_connection_setting('enp5s0f0/ipv4/method')
        .with_value('manual')
    end

    it { is_expected.to contain_networkmanager__vlan('enp5s0f0.1000') }
    it do
      is_expected.to contain_networkmanager__infiniband('ibp4s0')
        .with_ip6_method('ignore')
    end
  end

  context 'with real-world data' do
    data = Psych.load(File.read(File.join('spec', 'fixtures', 'foreman_interfaces', 'realworld.yml')))

    let(:facts) { data['facts'] }
    let(:node_params) do
      {
        'foreman_interfaces' => data['foreman_interfaces'],
        'domainname' => 'example.com'
      }
    end

    it { is_expected.to compile }

    it do
      is_expected.to contain_networkmanager__ethernet('enp2s0f0')
        .with_mac('3C:4A:92:F6:CE:10')
        .with_ip4_addresses(['10.216.252.20/24'])
        .with_ip4_never_default(false)
        .without_ip4_routes
        .with_ip6_addresses(['fcdd:ef55:17:f080::20/64'])
        .with_ip6_never_default(false)
        .without_ip6_routes

      is_expected.to contain_networkmanager__vlan('enp2s0f0.1')
        .with_mac('3C:4A:92:F6:CE:10')
        .with_ip4_addresses(['172.31.0.107/24'])
        .with_ip4_never_default(true)
        .without_ip6_addresses
    end
  end

  context 'with magic network' do
    data = Psych.load(File.read(File.join('spec', 'fixtures', 'foreman_interfaces', 'single_interface_zeroes.yml')))

    let(:facts) { data['facts'] }
    let(:node_params) do
      {
        'foreman_interfaces' => data['foreman_interfaces'],
        'domainname' => 'example.com'
      }
    end

    it { is_expected.to compile }

    it do
      is_expected.to contain_networkmanager__ethernet('eno1')
        .with_mac('5C:52:62:56:8A:C4')
        .without_ip4_addresses
        .with_ip4_dns_search('example.com')
        .without_ip4_dns
        .with_ip4_method('auto')
        .with_ip4_never_default(false)
        .without_ip4_routes
        .without_ip6_addresses
        .with_ip6_method('auto')
        .without_ip6_routes
        .with_ip6_never_default(false)
    end
  end
end
