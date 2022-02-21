# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ethernet' do
  let(:title) { 'Ethernet' }
  let(:params) do
    {
      mac: '00:01:02:03:04:05',
      mtu: 1400
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_file('/etc/NetworkManager/system-connections/Ethernet')
          .with_owner('root')
          .with_group('root')
          .with_mode('0600')
          .that_notifies('Exec[reload_ethernet_Ethernet]')
      end
      it { is_expected.to contain_exec('reload_ethernet_Ethernet') }
    end
  end
end
