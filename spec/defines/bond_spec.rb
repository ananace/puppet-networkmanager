# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager::bond' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      ensure: :active,
      mac: '00:01:02:03:04:05',
      mtu: 1400,
      slaves: ['em1', 'em2'],
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_networkmanager_connection('namevar')
          .with_ensure('active')
          .with_purge_settings(true)
      end
      it { is_expected.to contain_networkmanager_connection_setting('namevar/ipv4/method') }
      it { is_expected.to contain_networkmanager_connection_setting('namevar/ipv6/method') }

      ['em1', 'em2'].each do |slave|
        it do
          is_expected.to contain_networkmanager_connection("bondslave-namevar-#{slave}")
            .with_ensure('present')
            .with_purge_settings(true)
        end
        it do
          is_expected.to contain_networkmanager_connection_setting("bondslave-namevar-#{slave}/connection/type")
            .with_value('ethernet')
        end
        it do
          is_expected.to contain_networkmanager_connection_setting("bondslave-namevar-#{slave}/connection/slave-type")
            .with_value('bond')
        end
        it do
          is_expected.to contain_networkmanager_connection_setting("bondslave-namevar-#{slave}/connection/master")
            .with_value('namevar')
        end

        it { is_expected.not_to contain_networkmanager_connection_setting("bondslave-namevar-#{slave}/ipv4/method") }
        it { is_expected.not_to contain_networkmanager_connection_setting("bondslave-namevar-#{slave}/ipv6/method") }
      end
    end
  end
end
