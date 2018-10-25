# -*- coding: utf-8; -*-

# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# https://docs.puppetlabs.com/guides/tests_smoke.html


# This comment marks the beginning of example usage.

# Use the manifest we're testing itself here:
include networkmanager

# Nota bene: You can not control the order in which the external node
# classifier applies classes so your manifests need to work even when
# dependencies are applied after the resources that depend on them.

# Include required modules here:

# This comment marks the end of example usage.


# Most manifests created in pm-liuit will use some Nagios and
# Server_firewall defines so their dependencies will need to be
# loaded. We don't want to do that in the manifests however as those
# classes should be applied by the external node classifier in
# production.

# Test environment dependencies:
include yum
include yum::epel
include nagios::node

# Simulate properly set up firewall:
class { '::server_firewall':
  constricto_available => true,
  constricto_enabled   => true,
}

# Declare required resources here:
service { [ 'network', 'rsyslog', ]:
}


# # # 