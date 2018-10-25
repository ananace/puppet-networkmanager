define networkmanager::ethernet(
  Stdlib::MAC $mac,
  String $identifier = $title,
  String $connection_name = $title,
  Optional[Integer[1280]] $mtu,

  Optional[Enum[manual,auto]] $ip4_method = undef,
  Optional[Variant[Stdlib::IP::Address::V4::CIDR, Array[Stdlib::IP::Address::V4::CIDR]]] $ip4_addresses = undef,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $ip4_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V4::Nosubnet]] $ip4_dns = undef,
  Optional[String] $ip4_dns_search = undef,

  Optional[Enum[manual,auto]] $ip6_method = undef,
  Optional[Variant[Variant[Stdlib::IP::Address::V6::Full,Stdlib::IP::Address::V6::Compressed,Stdlib::IP::Address::V6::Alternative], Array[Variant[Stdlib::IP::Address::V6::Full,Stdlib::IP::Address::V6::Compressed,Stdlib::IP::Address::V6::Alternative]]]] $ip6_addresses = undef,
  Optional[Stdlib::IP::Address::V6::Nosubnet] $ip6_gateway = undef,
  Optional[Array[Stdlib::IP::Address::V6::Nosubnet]] $ip6_dns = undef,
  Optional[String] $ip6_dns_search = undef,
) {
  $_ip4_addresses = flatten([$ip4_addresses])
  $_extra_ip4_addresses = $_ip4_addresses[1,-1]
  $_ip6_addresses = flatten([$ip6_addresses])
  $_extra_ip6_addresses = $_ip6_addresses[1,-1]

  $_ip4_method = pick($ip4_method, (length($_ip4_addresses) > 0) ? {
      true  => 'manual',
      false => 'auto',
  })
  $_ip6_method = pick($ip6_method, (length($_ip6_addresses) > 0) ? {
      true  => 'manual',
      false => 'auto',
  })

  $_uuid = inline_template("<% require 'zlib' -%><%= Random.new(Zlib::crc32 '${mac}-${identifier}').bytes(16).unpack('H8H4H4H4H12').join('-').gsub(/(?<b>\\S{14})\\S(?<a>\\S+)/, '\\k<b>4\\k<a>') %>")

  $_file = "/etc/NetworkManager/system-connections/${connection_name}"
  file { $_file:
    ensure  => file,
    content => epp('networkmanager/ethernet.epp', {
        identifier     => $identifier,
        mac            => $mac,
        mtu            => $mtu,
        uuid           => $_uuid,

        ip             => $_ip4_addresses[0],
        extra_ip       => $_extra_ip4_addresses,
        ip_gateway     => $ip4_gateway,
        ip_method      => $_ip4_method,
        ip4_dns        => $ip4_dns,
        ip4_dns_search => $ip4_dns_search,

        ip6            => $_ip6_addresses[0],
        extra_ip6      => $_extra_ip6_addresses,
        ip6_gateway    => $ip6_gateway,
        ip6_method     => $_ip6_method,
        ip6_dns        => $ip6_dns,
        ip6_dns_search => $ip6_dns_search,
    }),
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    notify  => Exec["reload_ethernet_${title}"],
  }
  exec { "reload_ethernet_${title}":
    command     => "/usr/bin/nmcli c load ${_file} && /usr/bin/nmcli c up uuid ${_uuid}",
    refreshonly => true,
  }
}
