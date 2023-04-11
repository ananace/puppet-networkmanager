define networkmanager::connection (
  String $type,
  String $connection_name = $title,
  Boolean $autoconnect = true,
  Boolean $bare = false,

  Enum[present,absent,active] $ensure = 'present',
  Boolean $purge_settings = true,

  Optional[Enum[disabled,shared,manual,auto]] $ip4_method = undef,
  Optional[Variant[Stdlib::IP::Address::V4::CIDR, Array[Stdlib::IP::Address::V4::CIDR]]] $ip4_addresses = undef,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $ip4_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V4::Nosubnet]] $ip4_dns = undef,
  Optional[Array[Stdlib::IP::Address::V4::CIDR]] $ip4_routes = undef,
  Optional[String] $ip4_dns_search = undef,
  Optional[Boolean] $ip4_may_fail = undef,
  Optional[Boolean] $ip4_never_default = undef,

  Optional[Enum[dhcp,'link-local',manual,auto,ignore]] $ip6_method = undef,
  Optional[Variant[Stdlib::IP::Address::V6::CIDR, Array[Stdlib::IP::Address::V6::CIDR]]] $ip6_addresses = undef,
  Optional[Stdlib::IP::Address::V6::Nosubnet] $ip6_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V6::Nosubnet]] $ip6_dns = undef,
  Optional[Array[Stdlib::IP::Address::V6::CIDR]] $ip6_routes = undef,
  Optional[String] $ip6_dns_search = undef,
  Optional[Boolean] $ip6_may_fail = undef,
  Optional[Boolean] $ip6_never_default = undef,
) {
  $_ip4_addresses = flatten([pick($ip4_addresses, [])])
  $_ip6_addresses = flatten([pick($ip6_addresses, [])])

  if length($_ip4_addresses) > 0 {
    $_ip4_method = pick($ip4_method, 'manual')
    $_ip4_may_fail = pick($ip4_may_fail, false)
  } else {
    $_ip4_method = pick($ip4_method, 'auto')
    $_ip4_may_fail = pick($ip4_may_fail, true)
  }
  if length($_ip6_addresses) > 0 {
    $_ip6_method = pick($ip6_method, 'manual')
    $_ip6_may_fail = pick($ip6_may_fail, false)
  } else {
    $_ip6_method = pick($ip6_method, 'auto')
    $_ip6_may_fail = pick($ip6_may_fail, true)
  }

  networkmanager_connection { $connection_name:
    ensure         => $ensure,
    purge_settings => $purge_settings,
  }
  if $ensure != absent {
    networkmanager_connection_setting {
      "${connection_name}/connection/autoconnect": value => $autoconnect;
      "${connection_name}/connection/type": value        => $type;
    }

    if !$bare {
      networkmanager_connection_setting {
        "${connection_name}/ipv4/method": value => $_ip4_method;
        "${connection_name}/ipv6/method": value => $_ip6_method;
      }

      if length($_ip4_addresses) > 0 {
        $_ip4_addresses.each |$idx, $address| {
          networkmanager_connection_setting { "${connection_name}/ipv4/address${$idx + 1}":
            value => (($idx == 0 and $ip4_gateway) ? {
                true    => "${address},${ip4_gateway}",
                default => $address,
              }
            ),
          }
        }
      }
      networkmanager_connection_setting { "${connection_name}/ipv4/may-fail":
        value => $_ip4_may_fail,
      }
      if $ip4_dns {
        networkmanager_connection_setting { "${connection_name}/ipv4/dns":
          value => $ip4_dns.join(';'),
        }
      }
      if $ip4_dns_search {
        networkmanager_connection_setting { "${connection_name}/ipv4/dns-search":
          value => $ip4_dns_search,
        }
      }
      if $ip4_routes {
        $ip4_routes.each |$idx, $route| {
          networkmanager_connection_setting { "${connection_name}/ipv4/route${$idx + 1}":
            value => "${route},0.0.0.0,1",
          }
        }
      }
      if $ip4_never_default != undef {
        networkmanager_connection_setting { "${connection_name}/ipv4/never-default":
          value => $ip4_never_default,
        }
      }

      if length($_ip6_addresses) > 0 {
        $_ip6_addresses.each |$idx, $address| {
          networkmanager_connection_setting { "${connection_name}/ipv6/address${$idx + 1}":
            value => (($idx == 0 and $ip6_gateway) ? {
                true    => "${address},${ip6_gateway}",
                default => $address,
              }
            ),
          }
        }
      }
      networkmanager_connection_setting { "${connection_name}/ipv6/may-fail":
        value => $_ip6_may_fail,
      }
      if $ip6_dns {
        networkmanager_connection_setting { "${connection_name}/ipv6/dns":
          value => $ip6_dns.join(';'),
        }
      }
      if $ip6_dns_search {
        networkmanager_connection_setting { "${connection_name}/ipv6/dns-search":
          value => $ip6_dns_search,
        }
      }
      if $ip6_routes {
        $ip6_routes.each |$idx, $route| {
          networkmanager_connection_setting { "${connection_name}/ipv6/route${$idx + 1}":
            value => "${route},::,1",
          }
        }
      }
      if $ip6_never_default != undef {
        networkmanager_connection_setting { "${connection_name}/ipv6/never-default":
          value => $ip6_never_default,
        }
      }
    }
  }

  $_file = "/etc/NetworkManager/system-connections/${connection_name}.nmconnection"
  file { $_file:
    ensure  => stdlib::ensure($ensure != 'absent', 'file'),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    replace => false,
  }
}
