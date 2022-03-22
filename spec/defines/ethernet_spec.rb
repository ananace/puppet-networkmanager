# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::ethernet' do
  let(:title) { 'Ethernet' }
  let(:params) do
    {
      mac: '00:01:02:03:04:0a',
      mtu: 1400
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/autoconnect')
          .with_value(true)
          .that_notifies('Networkmanager_connection[Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/interface-name')
          .with_value('Ethernet')
          .that_notifies('Networkmanager_connection[Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/type')
          .with_value('ethernet')
          .that_notifies('Networkmanager_connection[Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ethernet/mac-address')
          .with_value('00:01:02:03:04:0a')
          .that_notifies('Networkmanager_connection[Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ipv4/method')
          .with_value('auto')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ipv6/method')
          .with_value('auto')
      end
      it { is_expected.not_to contain_networkmanager_connection_setting('Ethernet/ipv4/may-fail').with_value(false) }
      it { is_expected.not_to contain_networkmanager_connection_setting('Ethernet/ipv6/may-fail').with_value(false) }
      it do
        is_expected.to contain_networkmanager_connection('Ethernet')
          .with_ensure('present')
          .with_purge_settings(true)
      end
    end
  end
end
