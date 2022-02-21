class networkmanager::foreman_interfaces {
  networkmanager::munge_foreman_interfaces().each |$identifier, $iface| {
    if length($iface['mac']) == 17 {
      if $iface['virtual'] {
        networkmanager::vlan { $identifier:
          mac            => upcase($iface['mac']),
          vlanid         => Integer(pick($iface['tag'], $iface['vlan'])),
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
      } else {
        networkmanager::ethernet { $identifier:
          mac            => upcase($iface['mac']),
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
      }
    } else {
      networkmanager::infiniband { $identifier:
        mac            => upcase($iface['mac']),
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
    }
  }
}
