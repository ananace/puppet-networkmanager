# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:nm_package) do
        case os_facts[:os]['family']
        when 'Debian' then 'network-manager'
        when 'Gentoo' then 'net-misc/networkmanager'
        else 'NetworkManager'
        end
      end
      let(:nm_purge_service) do
        case os_facts[:os]['family']
        when 'Suse' then 'wicked'
        else 'network'
        end
      end

      it { is_expected.to compile.with_all_deps }

      it do
        is_expected.to contain_service('NetworkManager')
          .with_ensure('running')
          .with_enable(true)
          .with_require("Package[#{nm_package}]")
      end

      it { is_expected.to contain_package(nm_package).with_ensure('latest') }

      it do
        is_expected.to contain_file('/etc/NetworkManager/system-connections')
          .with_ensure('directory')
          .with_purge(false)
          .with_recurse(true)
      end

      it { is_expected.to contain_file('/etc/NetworkManager/conf.d').with_ensure('directory') }

      it { is_expected.not_to contain_file('/etc/NetworkManager/conf.d/NetworkManager.conf') }

      it { is_expected.not_to contain_service(nm_purge_service) }

      it { is_expected.not_to contain_tidy('/etc/sysconfig/network-scripts/') }

      if os_facts[:os]['family'] == 'Debian'
        it { is_expected.not_to contain_package('ifupdown') }

        it { is_expected.not_to contain_file('/etc/network/interfaces') }
      end

      context 'with param nm_package set to "networkmanager"' do
        let(:params) { { nm_package: 'networkmanager' } }

        it { is_expected.to contain_package('networkmanager') }
      end

      context 'with param manage_nm set to false' do
        let(:params) { { manage_nm: false } }

        it { is_expected.not_to contain_service('NetworkManager') }

        it { is_expected.not_to contain_package(nm_package) }
      end

      context 'with param purge_legacy set to true' do
        let(:params) { { purge_legacy: true } }

        it do
          is_expected.to contain_file('/etc/NetworkManager/conf.d/NetworkManager.conf')
            .with_ensure('file')
            .with_content(File.read('templates/networkmanager.conf.epp'))
            .with_owner('root')
            .with_group('root')
            .with_mode('0644')
            .with_notify('Service[NetworkManager]')
        end

        it { is_expected.to contain_service(nm_purge_service).with_enable(false) }

        it do
          is_expected.to contain_tidy('/etc/sysconfig/network-scripts/')
            .with_recurse(true)
            .with_matches(['ifcfg-*'])
        end

        if os_facts[:os]['family'] == 'Debian'
          it { is_expected.to contain_package('ifupdown').with_ensure('purged') }

          it do
            is_expected.to contain_file('/etc/network/interfaces')
              .with_ensure('file')
              .with_content(File.read('templates/interfaces.epp'))
              .with_owner('root')
              .with_group('root')
              .with_mode('0644')
          end
        end
      end
    end
  end
end
