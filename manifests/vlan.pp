define networkmanager::vlan(
  Stdlib::MAC $mac,
  Integer[1,4096] $vlanid,
  String $identifier = $title,
  String $connection_name = $title,
  Optional[Integer[1280]] $mtu,

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
  networkmanager::connection { "vlan ${title} - base connection":
    type            => 'vlan',
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
    "${connection_name}/ethernet/mac-address": value      => $mac;
    "${connection_name}/vlan/id": value                   => $vlanid;
    "${connection_name}/vlan/interface-name": value       => $identifier;
  }
  if $mtu {
    networkmanager_connection_setting { "${connection_name}/ethernet/mtu":
      value => $mtu,
    }
  }
}
