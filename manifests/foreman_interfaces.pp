class networkmanager::foreman_interfaces {
  $::foreman_interfaces.filter |$iface| {
    $iface['managed'] and $iface['type'] == 'Interface'
  }.reduce({}) |$hash, $iface| {
    if $iface['ip'] =~ Stdlib::IP::Address::V4 {
      $_ip = {
        ip     => $iface['ip'],
        subnet => $iface['subnet'],
      }
    }
    if $iface['ip6'] =~  Stdlib::IP::Address::V6 {
      $_ip6 = {
        ip     => $iface['ip6'],
        subnet => $iface['subnet6'],
      }
    }

    if !$iface['virtual'] or $iface['identifier'] =~ /^.+\..+$/ {
      if $iface['mac'] {
        $_mac = $iface['mac']
      } else {
        $_mac = $hash[$iface['attached_to']]['mac']
      }
      $hash + {
        $iface['identifier'] => {
          mac           => $_mac,
          tag           => $iface['tag'],
          ip_addresses  => delete_undef_values([ $_ip ]),
          ip6_addresses => delete_undef_values([ $_ip6 ]),
        }
      }
    } else {
      $existing = $hash[$iface['attached_to']]
      $hash + {
        $iface['attached_to'] => {
          mac           => $existing['mac'],
          ip_addresses  => delete_undef_values($existing['ip_addresses'] << $_ip),
          ip6_addresses => delete_undef_values($existing['ip6_addresses'] << $_ip6),
        }
      }
    }
  }.each |$identifier, $iface| {
    if length($iface['ip_addresses']) > 1 {
      $_ip_gateway = $iface['ip_addresses'][0]['subnet']['gateway']
      $_ip_method = 'manual'
    } elsif length($iface['ip_addresses']) == 1 {
      $_ip_gateway = $iface['ip_addresses'][0]['subnet']['gateway']
      $_ip_method = ($iface['ip_addresses'][0]['subnet']['boot_mode'] ? {
          'DHCP'   => 'auto',
          'Static' => 'manual',
          default  => undef,
      })
    }
    if length($iface['ip6_addresses']) > 1 {
      $_ip6_gateway = $iface['ip6_addresses'][0]['subnet']['gateway']
      $_ip6_method = 'manual'
    } elsif length($iface['ip6_addresses']) == 1 {
      $_ip6_gateway = $iface['ip6_addresses'][0]['subnet']['gateway']
      $_ip6_method = ($iface['ip6_addresses'][0]['subnet']['boot_mode'] ? {
          'DHCP'   => 'auto',
          'Static' => 'manual',
          default  => undef,
      })
    }

    $_ips = $iface['ip_addresses'].map |$if| {
      $_cidr = inline_template("<% require 'ipaddr' -%>\n<%= IPAddr.new('${if['subnet']['mask']}').to_i.to_s(2).count('1') %>")
      "${if['ip']}/${_cidr}"
    }
    $_mtus = $iface['ip_addresses'].map |$if| {
      $if['subnet']['mtu']
    }
    $_vlans = $iface['ip_addresses'].map |$if| {
      $if['subnet']['vlanid']
    }
    $_ip6s = $iface['ip6_addresses'].map |$if| {
      $_cidr = inline_template("<% require 'ipaddr' -%>\n<%= IPAddr.new('${if['subnet']['mask']}').to_i.to_s(2).count('1') %>")
      "${if['ip']}/${_cidr}"
    }
    $_mtu6s = $iface['ip6_addresses'].map |$if| {
      $if['subnet']['mtu']
    }
    $_vlan6s = $iface['ip_addresses'].map |$if| {
      $if['subnet']['vlanid']
    }

    $_dns4 = unique(flatten($iface['ip_addresses'].map |$if| { [$if['subnet']['dns_primary'], $if['subnet']['dns_secondary']] })).filter |$dns| { $dns =~ Stdlib::IP::Address::V4 }
    $_dns6 = unique(flatten($iface['ip6_addresses'].map |$if| { [$if['subnet']['dns_primary'], $if['subnet']['dns_secondary']] })).filter |$dns| { $dns =~  Stdlib::IP::Address::V6 }

    if length($iface['mac']) == 17 {
      if $identifier =~ /^.+\..+$/ {
        networkmanager::vlan { $identifier:
          mac            => upcase($iface['mac']),
          vlanid         => Integer(pick($iface['tag'], $_vlans[0])),
          mtu            => $_mtus[0],
          ip4_addresses  => $_ips,
          ip4_gateway    => $_ip_gateway,
          ip4_dns        => $_dns4,
          ip4_dns_search => $::domainname,
          ip4_method     => $_ip_method,
          ip6_addresses  => $_ip6s,
          ip6_gateway    => $_ip6_gateway,
          ip6_dns        => $_dns6,
          ip6_dns_search => $::domainname,
          ip6_method     => $_ip6_method,
        }
      } else {
        networkmanager::ethernet { $identifier:
          mac            => upcase($iface['mac']),
          mtu            => $_mtus[0],
          ip4_addresses  => $_ips,
          ip4_gateway    => $_ip_gateway,
          ip4_dns        => $_dns4,
          ip4_dns_search => $::domainname,
          ip4_method     => $_ip_method,
          ip6_addresses  => $_ip6s,
          ip6_gateway    => $_ip6_gateway,
          ip6_dns        => $_dns6,
          ip6_dns_search => $::domainname,
          ip6_method     => $_ip6_method,
        }
      }
    } elsif length($iface['mac']) == 59 {
      networkmanager::infiniband { $identifier:
        connection_name => $identifier,
        mac             => upcase($iface['mac']),
        mtu             => $_mtus[0],
        ip4_addresses   => $_ips,
        ip4_gateway     => $_ip_gateway,
        ip4_dns         => $_dns4,
        ip4_dns_search  => $::domainname,
        ip4_method      => $_ip_method,
        ip6_addresses   => $_ip6s,
        ip6_gateway     => $_ip6_gateway,
        ip6_dns         => $_dns6,
        ip6_dns_search  => $::domainname,
        ip6_method      => $_ip6_method,
      }
    }
  }
}
