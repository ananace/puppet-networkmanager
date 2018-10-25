# == Class: networkmanager
#
# Full description of class networkmanager here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array. Defaults
#   to []."
#
# === Examples
#
# @example
#    class { 'networkmanager':
#      sample_parameter => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# === Authors
#
# Author Name <author.name@liu.se>
#
# === Copyright
#
# Copyright 2018 Linköping University
#
class networkmanager(
  Array[String] $sample_parameter = []
) {
  notify { 'Example notify':
    message => "Parameter: ${sample_parameter}",
  }

  file { '/tmp/example.file':
    content => epp("${module_name}/example.epp"),
  }
}
