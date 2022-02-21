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
        .with_mac('00:11:22:33:44:55')
        .with_mtu(1500)
        .with_ip4_addresses(['1.2.3.4/8', '1.2.3.5/8'])
        .with_ip4_gateway('1.0.0.1')
        .with_ip4_dns(['1.0.1.1', '1.0.1.2'])
        .with_ip4_dns_search('example.com')
        .with_ip4_method('manual')
        .with_ip6_addresses(nil)
    end
    it { is_expected.to contain_networkmanager__vlan('enp5s0f0.1000') }
    it { is_expected.to contain_networkmanager__infiniband('ibp4s0') }
  end
end
