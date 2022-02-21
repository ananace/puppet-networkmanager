# frozen_string_literal: true

require 'spec_helper'

CONTEXTS = {
  single_interface: {
    facts: {
      'networking' => {
        'interfaces' => {
          'eno1' => {
            'bindings' => [
              {
                'address' => '10.1.2.3',
                'netmask' => '255.255.255.0',
                'network' => '10.1.2.0'
              }
            ],
            'bindings6' => [
              {
                'address' => 'fc99:6b0:17:2300::13',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fc99:6b0:17:2300::'
              },
              {
                'address' => 'fe80::4e52:62ff:fe56:8aa3',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fe80::'
              }
            ],
            'ip' => '10.1.2.3',
            'ip6' => 'fc99:6b0:17:2300::13',
            'mac' => '5c:52:62:56:8a:a3',
            'mtu' => 1500,
            'netmask' => '255.255.255.0',
            'netmask6' => 'ffff:ffff:ffff:ffff::',
            'network' => '10.1.2.0',
            'network6' => 'fc99:6b0:17:2300::',
            'scope6' => 'global'
          }
        }
      }
    },
    foreman_interfaces: [
      {
        'ip' => '10.1.2.3',
        'ip6' => 'fc99:6b0:17:2300::12',
        'mac' => '5c:52:62:56:8a:c4',
        'name' => 'single_interface.example.com',
        'attrs' => {},
        'virtual' => false,
        'link' => true,
        'identifier' => 'eno1',
        'managed' => true,
        'primary' => true,
        'provision' => true,
        'subnet' => {
          'name' => 'Test network',
          'network' => '10.1.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.1.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.1.2.10',
          'to' => '10.1.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => {
          'name' => 'Test network v6',
          'network' => 'fc99:6b0:17:2300::',
          'mask' => 'ffff:ffff:ffff:ffff::',
          'gateway' => 'fc99:6b0:17:2300::1',
          'dns_primary' => '1::1',
          'dns_secondary' => '1::2',
          'from' => 'fc99:6b0:17:2300::2',
          'to' => 'fc99:6b0:17:2300:ffff:ffff:ffff:ffff',
          'boot_mode' => 'Static',
          'ipam' => 'Internal DB',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv6',
          'description' => ''
        },
        'tag' => nil,
        'attached_to' => nil,
        'type' => 'Interface'
      }
    ],
    result: {
      'eno1'=> {
        :virtual => false,
        :mac => '5c:52:62:56:8a:c4',
        :vlan => 1010,
        :mtu => 1500,
        :dhcp4 => false,
        :mtu4 => 1500,
        :gateway4 => '10.1.2.1',
        :ips4 => ['10.1.2.3'],
        :netmasks4 => ['255.255.255.0'],
        :cidrs4 => ['10.1.2.3/24'],
        :dns4 => ['1.1.1.1', '1.1.2.2'],
        :dhcp6 => false,
        :mtu6 => 1500,
        :gateway6 => 'fc99:6b0:17:2300::1',
        :ips6 => ['fc99:6b0:17:2300::12'],
        :netmasks6 => ['ffff:ffff:ffff:ffff::'],
        :cidrs6 =>['fc99:6b0:17:2300::12/64'],
        :dns6 => ['1::1', '1::2']
      }
    }
  },
  single_interface_no_identifier: {
    facts: {
      'networking' => {
        'interfaces' => {
          'eno1' => {
            'bindings' => [
              {
                'address' => '10.1.2.3',
                'netmask' => '255.255.255.0',
                'network' => '10.1.2.0'
              }
            ],
            'bindings6' => [
              {
                'address' => 'fc99:6b0:17:2300::13',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fc99:6b0:17:2300::'
              },
              {
                'address' => 'fe80::4e52:62ff:fe56:8aa3',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fe80::'
              }
            ],
            'ip' => '10.1.2.3',
            'ip6' => 'fc99:6b0:17:2300::13',
            'mac' => '5c:52:62:56:8a:a3',
            'mtu' => 1500,
            'netmask' => '255.255.255.0',
            'netmask6' => 'ffff:ffff:ffff:ffff::',
            'network' => '10.1.2.0',
            'network6' => 'fc99:6b0:17:2300::',
            'scope6' => 'global'
          }
        }
      }
    },
    foreman_interfaces: [
      {
        'ip' => '10.1.2.3',
        'ip6' => 'fc99:6b0:17:2300::12',
        'mac' => '5c:52:62:56:8a:c4',
        'name' => 'single_interface.example.com',
        'attrs' => {},
        'virtual' => false,
        'link' => true,
        'identifier' => '',
        'managed' => true,
        'primary' => true,
        'provision' => true,
        'subnet' => {
          'name' => 'Test network',
          'network' => '10.1.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.1.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.1.2.10',
          'to' => '10.1.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => {
          'name' => 'Test network v6',
          'network' => 'fc99:6b0:17:2300::',
          'mask' => 'ffff:ffff:ffff:ffff::',
          'gateway' => 'fc99:6b0:17:2300::1',
          'dns_primary' => '1::1',
          'dns_secondary' => '1::2',
          'from' => 'fc99:6b0:17:2300::2',
          'to' => 'fc99:6b0:17:2300:ffff:ffff:ffff:ffff',
          'boot_mode' => 'Static',
          'ipam' => 'Internal DB',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv6',
          'description' => ''
        },
        'tag' => nil,
        'attached_to' => nil,
        'type' => 'Interface'
      }
    ],
    result: {
      'eno1'=> {
        :virtual => false,
        :mac => '5c:52:62:56:8a:c4',
        :vlan => 1010,
        :mtu => 1500,
        :dhcp4 => false,
        :mtu4 => 1500,
        :gateway4 => '10.1.2.1',
        :ips4 => ['10.1.2.3'],
        :netmasks4 => ['255.255.255.0'],
        :cidrs4 => ['10.1.2.3/24'],
        :dns4 => ['1.1.1.1', '1.1.2.2'],
        :dhcp6 => false,
        :mtu6 => 1500,
        :gateway6 => 'fc99:6b0:17:2300::1',
        :ips6 => ['fc99:6b0:17:2300::12'],
        :netmasks6 => ['ffff:ffff:ffff:ffff::'],
        :cidrs6 =>['fc99:6b0:17:2300::12/64'],
        :dns6 => ['1::1', '1::2']
      }
    }
  },
  vlan: {
    facts: {
      'networking' => {
        'interfaces' => {
          'eno1' => {
            'bindings' => [
              {
                'address' => '10.1.2.3',
                'netmask' => '255.255.255.0',
                'network' => '10.1.2.0'
              }
            ],
            'bindings6' => [
              {
                'address' => 'fc99:6b0:17:2300::13',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fc99:6b0:17:2300::'
              },
              {
                'address' => 'fe80::4e52:62ff:fe56:8aa3',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fe80::'
              }
            ],
            'ip' => '10.1.2.3',
            'ip6' => 'fc99:6b0:17:2300::13',
            'mac' => '5c:52:62:56:8a:a3',
            'mtu' => 1500,
            'netmask' => '255.255.255.0',
            'netmask6' => 'ffff:ffff:ffff:ffff::',
            'network' => '10.1.2.0',
            'network6' => 'fc99:6b0:17:2300::',
            'scope6' => 'global'
          }
        }
      }
    },
    foreman_interfaces: [
      {
        'ip' => '10.1.2.3',
        'ip6' => 'fc99:6b0:17:2300::12',
        'mac' => '5c:52:62:56:8a:c4',
        'name' => 'single_interface.example.com',
        'attrs' => {},
        'virtual' => false,
        'link' => true,
        'identifier' => '',
        'managed' => true,
        'primary' => true,
        'provision' => true,
        'subnet' => {
          'name' => 'Test network',
          'network' => '10.1.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.1.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.1.2.10',
          'to' => '10.1.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => {
          'name' => 'Test network v6',
          'network' => 'fc99:6b0:17:2300::',
          'mask' => 'ffff:ffff:ffff:ffff::',
          'gateway' => 'fc99:6b0:17:2300::1',
          'dns_primary' => '1::1',
          'dns_secondary' => '1::2',
          'from' => 'fc99:6b0:17:2300::2',
          'to' => 'fc99:6b0:17:2300:ffff:ffff:ffff:ffff',
          'boot_mode' => 'Static',
          'ipam' => 'Internal DB',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv6',
          'description' => ''
        },
        'tag' => nil,
        'attached_to' => nil,
        'type' => 'Interface'
      },
      {
        'ip' => '10.2.2.3',
        'ip6' => '',
        'mac' => nil,
        'name' => 'single_interface.internal.example.com',
        'attrs' => {},
        'virtual' => true,
        'link' => true,
        'identifier' => 'eno1.1',
        'managed' => true,
        'primary' => false,
        'provision' => false,
        'subnet' => {
          'name' => 'Internal network',
          'network' => '10.2.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.2.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.2.2.10',
          'to' => '10.2.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => nil,
        'tag' => '',
        'attached_to' => 'eno1',
        'type' => 'Interface'
      }
    ],
    result: {
      'eno1'=> {
        :virtual => false,
        :mac => '5c:52:62:56:8a:c4',
        :vlan => 1010,
        :mtu => 1500,
        :dhcp4 => false,
        :mtu4 => 1500,
        :gateway4 => '10.1.2.1',
        :ips4 => ['10.1.2.3'],
        :netmasks4 => ['255.255.255.0'],
        :cidrs4 => ['10.1.2.3/24'],
        :dns4 => ['1.1.1.1', '1.1.2.2'],
        :dhcp6 => false,
        :mtu6 => 1500,
        :gateway6 => 'fc99:6b0:17:2300::1',
        :ips6 => ['fc99:6b0:17:2300::12'],
        :netmasks6 => ['ffff:ffff:ffff:ffff::'],
        :cidrs6 =>['fc99:6b0:17:2300::12/64'],
        :dns6 => ['1::1', '1::2']
      },
      'eno1.1'=> {
        :virtual => true,
        :mac => '5c:52:62:56:8a:c4',
        :tag => 1,
        :vlan => 1,
        :mtu => 1500,
        :dhcp4 => false,
        :mtu4 => 1500,
        :gateway4 => '10.2.2.1',
        :ips4 => ['10.2.2.3'],
        :netmasks4 => ['255.255.255.0'],
        :cidrs4 => ['10.2.2.3/24'],
        :dns4 => ['1.1.1.1', '1.1.2.2'],
      }
    }
  },
  multi_address: {
    facts: {
      'networking' => {
        'interfaces' => {
          'eno1' => {
            'bindings' => [
              {
                'address' => '10.1.2.3',
                'netmask' => '255.255.255.0',
                'network' => '10.1.2.0'
              }
            ],
            'bindings6' => [
              {
                'address' => 'fc99:6b0:17:2300::13',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fc99:6b0:17:2300::'
              },
              {
                'address' => 'fe80::4e52:62ff:fe56:8aa3',
                'netmask' => 'ffff:ffff:ffff:ffff::',
                'network' => 'fe80::'
              }
            ],
            'ip' => '10.1.2.3',
            'ip6' => 'fc99:6b0:17:2300::13',
            'mac' => '5c:52:62:56:8a:a3',
            'mtu' => 1500,
            'netmask' => '255.255.255.0',
            'netmask6' => 'ffff:ffff:ffff:ffff::',
            'network' => '10.1.2.0',
            'network6' => 'fc99:6b0:17:2300::',
            'scope6' => 'global'
          }
        }
      }
    },
    foreman_interfaces: [
      {
        'ip' => '10.1.2.3',
        'ip6' => 'fc99:6b0:17:2300::12',
        'mac' => '5c:52:62:56:8a:c4',
        'name' => 'single_interface.example.com',
        'attrs' => {},
        'virtual' => false,
        'link' => true,
        'identifier' => '',
        'managed' => true,
        'primary' => true,
        'provision' => true,
        'subnet' => {
          'name' => 'Test network',
          'network' => '10.1.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.1.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.1.2.10',
          'to' => '10.1.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => {
          'name' => 'Test network v6',
          'network' => 'fc99:6b0:17:2300::',
          'mask' => 'ffff:ffff:ffff:ffff::',
          'gateway' => 'fc99:6b0:17:2300::1',
          'dns_primary' => '1::1',
          'dns_secondary' => '1::2',
          'from' => 'fc99:6b0:17:2300::2',
          'to' => 'fc99:6b0:17:2300:ffff:ffff:ffff:ffff',
          'boot_mode' => 'Static',
          'ipam' => 'Internal DB',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv6',
          'description' => ''
        },
        'tag' => nil,
        'attached_to' => nil,
        'type' => 'Interface'
      },
      {
        'ip' => '10.1.2.4',
        'ip6' => '',
        'mac' => nil,
        'name' => 'second_interface.example.com',
        'attrs' => {},
        'virtual' => true,
        'link' => true,
        'identifier' => 'eno1:1',
        'managed' => true,
        'primary' => false,
        'provision' => false,
        'subnet' => {
          'name' => 'Test network',
          'network' => '10.1.2.0',
          'mask' => '255.255.255.0',
          'gateway' => '10.1.2.1',
          'dns_primary' => '1.1.1.1',
          'dns_secondary' => '1.1.2.2',
          'from' => '10.1.2.10',
          'to' => '10.1.2.239',
          'boot_mode' => 'Static',
          'ipam' => 'DHCP',
          'vlanid' => 1010,
          'mtu' => 1500,
          'nic_delay' => nil,
          'network_type' => 'IPv4',
          'description' => ''
        },
        'subnet6' => nil,
        'tag' => '',
        'attached_to' => 'eno1',
        'type' => 'Interface'
      }
    ],
    result: {
      'eno1'=> {
        :virtual => false,
        :mac => '5c:52:62:56:8a:c4',
        :vlan => 1010,
        :mtu => 1500,
        :dhcp4 => false,
        :mtu4 => 1500,
        :gateway4 => '10.1.2.1',
        :ips4 => ['10.1.2.3', '10.1.2.4'],
        :netmasks4 => ['255.255.255.0', '255.255.255.0'],
        :cidrs4 => ['10.1.2.3/24', '10.1.2.4/24'],
        :dns4 => ['1.1.1.1', '1.1.2.2'],
        :dhcp6 => false,
        :mtu6 => 1500,
        :gateway6 => 'fc99:6b0:17:2300::1',
        :ips6 => ['fc99:6b0:17:2300::12'],
        :netmasks6 => ['ffff:ffff:ffff:ffff::'],
        :cidrs6 =>['fc99:6b0:17:2300::12/64'],
        :dns6 => ['1::1', '1::2']
      }
    }
  }
}

describe 'networkmanager::munge_foreman_interfaces' do
  it { is_expected.not_to eq(nil) }

  CONTEXTS.each do |name, data|
    context "with #{name}" do
      before(:each) do
        expect(scope).to receive(:[]).with('facts').and_return(data[:facts])
        expect(scope).to receive(:[]).with('foreman_interfaces').and_return(data[:foreman_interfaces])
      end

      it { is_expected.to run.and_return(data[:result]) }
    end
  end
end
