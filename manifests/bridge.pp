define networkmanager::bridge(
  String $identifier = $title,
  String $connection_name = $title,
  Optional[Integer[1280]] $mtu = undef,
  Optional[Stdlib::MAC] $mac = undef,

  Enum[present,absent,active] $ensure = 'present',
  Boolean $purge_settings = true,

  Hash[String,Data] $options = {},
  Array[String] $slaves = [],

  Optional[Enum[disabled,shared,manual,auto]] $ip4_method = undef,
  Optional[Variant[Stdlib::IP::Address::V4::CIDR, Array[Stdlib::IP::Address::V4::CIDR]]] $ip4_addresses = undef,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $ip4_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V4::Nosubnet]] $ip4_dns = undef,
  Optional[String] $ip4_dns_search = undef,

  Optional[Enum[dhcp,'link-local',manual,auto,ignore]] $ip6_method = undef,
  Optional[Variant[Stdlib::IP::Address::V6::CIDR, Array[Stdlib::IP::Address::V6::CIDR]]] $ip6_addresses = undef,
  Optional[Stdlib::IP::Address::V6::Nosubnet] $ip6_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V6::Nosubnet]] $ip6_dns = undef,
  Optional[String] $ip6_dns_search = undef,
) {
  networkmanager::connection { "bridge ${title} - base connection":
    ensure          => $ensure,
    purge_settings  => $purge_settings,

    type            => 'bridge',
    connection_name => $connection_name,

    ip4_method      => $ip4_method,
    ip4_addresses   => $ip4_addresses,
    ip4_gateway     => $ip4_gateway,
    ip4_dns         => $ip4_dns,
    ip4_dns_search  => $ip4_dns_search,

    ip6_method      => $ip6_method,
    ip6_addresses   => $ip6_addresses,
    ip6_gateway     => $ip6_gateway,
    ip6_dns         => $ip6_dns,
    ip6_dns_search  => $ip6_dns_search,
  }

  networkmanager_connection_setting {
    "${connection_name}/connection/interface-name": value => $identifier;
  }
  if $mac {
    networkmanager_connection_setting {
      "${connection_name}/bridge/mac-address": value => $mac;
    }
  }
  $options.each |$option, $value| {
    networkmanager_connection_setting {
      "${connection_name}/bridge/${option}": value => $value;
    }
  }

  if $mtu {
    networkmanager_connection_setting { "${connection_name}/ethernet/mtu":
      value => $mtu,
    }
  }

  $slaves.each |$slave| {
    $slave_ensure = $ensure ? {
      absent  => absent,
      default => present,
    }
    $name = "bridgeslave-${identifier}-${slave}"
    networkmanager::connection { "bridge ${title} - bridgeslave ${slave}":
      ensure          => $slave_ensure,
      type            => 'ethernet',
      connection_name => $name,
      bare            => true,
    }
    networkmanager_connection_setting {
      "${name}/connection/interface-name": value => $slave;
      "${name}/connection/slave-type": value     => 'bridge';
      "${name}/connection/master": value         => $identifier;
    }
  }
}
