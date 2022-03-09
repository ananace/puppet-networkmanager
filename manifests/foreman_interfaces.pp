class networkmanager::foreman_interfaces {
  networkmanager::munge_foreman_interfaces().each |$identifier, $iface| {
    $base_params = {
      mtu            => $iface['mtu'],
      ip4_addresses  => $iface['cidrs4'],
      ip4_gateway    => $iface['gateway4'],
      ip4_dns        => $iface['dns4'],
      ip4_dns_search => $::domainname,
      ip4_method     => ($iface['dhcp4'] ? { true => 'auto', default => 'manual' }),
      ip6_addresses  => $iface['cidrs6'],
      ip6_gateway    => $iface['gateway6'],
      ip6_dns        => $iface['dns6'],
      ip6_dns_search => $::domainname,
      ip6_method     => ($iface['dhcp6'] ? { true => 'auto', default => 'manual' }),
    }

    case $iface['type'] {
      'Interface': {
        if length($iface['mac']) == 17 {
          if $iface['virtual'] {
            $type = 'networkmanager::vlan'
            $addn_params = {
              mac    => upcase($iface['mac']),
              vlanid => Integer(pick($iface['tag'], $iface['vlan'])),
            }
          } else {
            $type = 'networkmanager::ethernet'
            $addn_params = {
              mac => upcase($iface['mac']),
            }
          }
        } else {
          $type = 'networkmanager::infiniband'
          $addn_params = {
            mac => upcase($iface['mac']),
          }
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
              }
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
    }

    ensure_resource($type, $identifier, $base_params + $addn_params)
  }
}
