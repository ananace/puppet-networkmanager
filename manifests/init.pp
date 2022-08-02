class networkmanager (
  $nm_package = $networkmanager::nm_package,
  Boolean $manage_nm = true,
  Boolean $purge_connections = false,
  Boolean $purge_legacy = false,
) {
  if $manage_nm {
    service { 'NetworkManager':
      ensure  => running,
      enable  => true,
      require => Package[$nm_package],
    }
    package { $nm_package:
      ensure => latest,
    }
  }

  file { '/etc/NetworkManager/system-connections':
    ensure  => directory,
    purge   => $purge_connections,
    recurse => true,
  }
  if $purge_legacy {
    file { '/etc/NetworkManager/conf.d/NetworkManager.conf':
      ensure  => file,
      content => epp('networkmanager/networkmanager.conf.epp'),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      notify  => Service['NetworkManager'],
    }
    service { 'network':
      enable    => false,
    }
    tidy { '/etc/sysconfig/network-scripts/':
      recurse => true,
      matches => ['ifcfg-*'],
    }
    if $facts['os']['family'] == 'Debian' {
      package { 'ifupdown':
        ensure => purged,
      }
      file { '/etc/network/interfaces':
        ensure  => file,
        content => epp('networkmanager/interfaces.epp'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
      }
    }
  }
}
