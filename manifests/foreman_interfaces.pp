class networkmanager::foreman_interfaces {
  networkmanager::munge_foreman_interfaces().each |$identifier, $iface| {
    if $iface['attached_to'] != undef {
      $_ensure = 'present'
    } else {
      $_ensure = 'active'
    }

    $base_params = {
      ensure            => $_ensure,
      purge_settings    => true,

      mac               => ($iface['mac'] ? {
          undef   => undef,
          default => upcase($iface['mac']),
        }
      ),
      mtu               => $iface['mtu'],

      ip4_addresses     => $iface['cidrs4'],
      ip4_gateway       => $iface['gateway4'],
      ip4_dns           => $iface['dns4'],
      ip4_dns_search    => ($iface['dhcp4'] ? { undef => undef, default => $::domainname }),
      ip4_method        => ($iface['roaming'] ? {
          true => 'auto',
          default => ($iface['dhcp4'] ? {
              true    => 'auto',
              undef   => 'disabled',
              default => 'manual',
            }
          ),
        }
      ),
      ip4_never_default => !$iface['primary'],

      ip6_addresses     => $iface['cidrs6'],
      ip6_gateway       => $iface['gateway6'],
      ip6_dns           => $iface['dns6'],
      ip6_dns_search    => ($iface['dhcp6'] ? { undef => undef, default => $::domainname }),
      ip6_method        => ($iface['roaming'] ? {
          true => 'auto',
          default => ($iface['dhcp6'] ? {
              true    => 'auto',
              undef   => 'ignore',
              default => 'manual',
            }
          ),
        }
      ),
      ip6_never_default => !$iface['primary'],
    }

    case $iface['type'] {
      'Interface': {
        if length($iface['mac']) == 17 {
          if $iface['virtual'] {
            $type = 'networkmanager::vlan'
            $addn_params = {
              vlanid => Integer(pick($iface['tag'], $iface['vlan'])),
            }
          } else {
            $type = 'networkmanager::ethernet'
            $addn_params = {}
          }
        } else {
          $type = 'networkmanager::infiniband'
          $addn_params = {}
        }
      }

      'Bond': {
        if $identifier =~ /team.*/ {
          $type = 'networkmanager::team'
          $team_mode = $iface['mode'] ? {
            '802.3ad'       => 'lacp',
            'broadcast'     => 'broadcast',
            'balance-rr'    => 'roundrobin',
            'active-backup' => 'activebackup',
            default         => 'loadbalance',
          }
          $addn_params = {
            slaves => $iface['attached_devices'],
            config => {
              runner => {
                name    => $team_mode,
                tx_hash => [ 'eth', 'ip' ],
              },
            },
          }
        } else {
          $type = 'networkmanager::bond'
          $addn_params = {
            mode    => $iface['mode'],
            options => $iface['bond_options'],
            slaves  => $iface['attached_devices'],
          }
        }
      }

      'Bridge': {
        $type = 'networkmanager::bridge'
        $addn_params = {
          slaves => $iface['attached_devices'],
        }
      }

      default: {
        fail("Unknown interface type ${iface['type']} for ${iface}")
      }
    }

    ensure_resource($type, $identifier, $base_params + $addn_params)
  }
}
