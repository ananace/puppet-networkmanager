define networkmanager::bond (
  String $identifier = $title,
  String $connection_name = $title,
  Optional[Integer[1280]] $mtu = undef,
  Optional[Stdlib::MAC] $mac = undef,

  Networkmanager::Connectionensure $ensure = 'present',
  Boolean $autoconnect = true,
  Optional[Integer[-999,999]] $autoconnect_priority = undef,
  Boolean $purge_settings = true,

  Enum['balance-rr','active-backup','balance-xor','broadcast','802.3ad','balance-tlb','balance-alb'] $mode = 'balance-rr',
  Hash[String,Data] $options = {},
  Array[String] $slaves = [],

  Optional[Networkmanager::Connectionip4method] $ip4_method = undef,
  Optional[Variant[Stdlib::IP::Address::V4::CIDR, Array[Stdlib::IP::Address::V4::CIDR]]] $ip4_addresses = undef,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $ip4_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V4::Nosubnet]] $ip4_dns = undef,
  Optional[Variant[Stdlib::Fqdn, Array[Stdlib::Fqdn]]] $ip4_dns_search = undef,
  Optional[Array[Stdlib::IP::Address::V4::CIDR]] $ip4_routes = undef,
  Optional[Integer[-1]] $ip4_route_metric = undef,
  Optional[Boolean] $ip4_may_fail = undef,
  Optional[Boolean] $ip4_never_default = undef,

  Optional[Networkmanager::Connectionip6method] $ip6_method = undef,
  Optional[Variant[Stdlib::IP::Address::V6::CIDR, Array[Stdlib::IP::Address::V6::CIDR]]] $ip6_addresses = undef,
  Optional[Stdlib::IP::Address::V6::Nosubnet] $ip6_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V6::Nosubnet]] $ip6_dns = undef,
  Optional[Variant[Stdlib::Fqdn, Array[Stdlib::Fqdn]]] $ip6_dns_search = undef,
  Optional[Array[Stdlib::IP::Address::V6::CIDR]] $ip6_routes = undef,
  Optional[Integer[-1]] $ip6_route_metric = undef,
  Optional[Boolean] $ip6_may_fail = undef,
  Optional[Boolean] $ip6_never_default = undef,
) {
  networkmanager::connection { "bond ${title} - base connection":
    ensure               => $ensure,
    autoconnect          => $autoconnect,
    autoconnect_priority => $autoconnect_priority,
    purge_settings       => $purge_settings,

    type                 => 'bond',
    connection_name      => $connection_name,

    ip4_method           => $ip4_method,
    ip4_addresses        => $ip4_addresses,
    ip4_gateway          => $ip4_gateway,
    ip4_dns              => $ip4_dns,
    ip4_dns_search       => $ip4_dns_search,
    ip4_routes           => $ip4_routes,
    ip4_route_metric     => $ip4_route_metric,
    ip4_may_fail         => $ip4_may_fail,
    ip4_never_default    => $ip4_never_default,

    ip6_method           => $ip6_method,
    ip6_addresses        => $ip6_addresses,
    ip6_gateway          => $ip6_gateway,
    ip6_dns              => $ip6_dns,
    ip6_dns_search       => $ip6_dns_search,
    ip6_routes           => $ip6_routes,
    ip6_route_metric     => $ip6_route_metric,
    ip6_may_fail         => $ip6_may_fail,
    ip6_never_default    => $ip6_never_default,
  }

  if $ensure != absent {
    networkmanager_connection_setting {
      "${connection_name}/connection/interface-name": value => $identifier;
    }
    if $mac {
      networkmanager_connection_setting {
        "${connection_name}/ethernet/mac-address": value => $mac;
      }
    }
    if $mtu {
      networkmanager_connection_setting {
        "${connection_name}/ethernet/mtu": value => $mtu,
      }
    }
    $_bondconfig = $options + { mode => $mode }
    $_bondconfig.each |$key, $value| {
      networkmanager_connection_setting {
        "${connection_name}/bond/${key}": value => $value,
      }
    }
  }

  $slaves.each |$slave| {
    $slave_ensure = $ensure ? {
      'absent' => absent,
      default  => present,
    }
    $name = "bondslave-${identifier}-${slave}"
    networkmanager::connection { "bond ${title} - bondslave ${slave}":
      ensure          => $slave_ensure,
      type            => 'ethernet',
      connection_name => $name,
      bare            => true,
    }
    if $slave_ensure != absent {
      networkmanager_connection_setting {
        "${name}/connection/interface-name": value => $slave;
        "${name}/connection/slave-type": value => 'bond';
        "${name}/connection/master": value => $identifier;
      }
    }
  }
}
