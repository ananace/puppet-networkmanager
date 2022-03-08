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
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/autoconnect')
          .with_value(true)
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/id')
          .with_value('Ethernet')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/interface-name')
          .with_value('Ethernet')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/type')
          .with_value('ethernet')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/connection/uuid')
          .with(
            value: %r{[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}}i,
            replace: false
          )
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ethernet/mac-address')
          .with_value('00:01:02:03:04:05')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ipv4/method')
          .with_value('auto')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it do
        is_expected.to contain_networkmanager_connection_setting('Ethernet/ipv6/method')
          .with_value('auto')
          .that_notifies('Exec[reload_networkmanager_Ethernet]')
      end
      it { is_expected.to contain_exec('reload_networkmanager_Ethernet') }
    end
  end
end
