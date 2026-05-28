# Base OS profile — included by all roles.
# Handles common OS-level configuration shared across all node types.
class profile::base::base (
  Boolean $manage_ntp     = lookup('profile::base::manage_ntp', Boolean, 'first', true),
  Boolean $manage_syslog  = lookup('profile::base::manage_syslog', Boolean, 'first', true),
  Boolean $manage_utils   = lookup('profile::base::manage_utils', Boolean, 'first', true),
) {

  if $manage_utils {
    include base_utils
  }

  if $manage_ntp and $facts['kernel'] == 'Linux' {
    package { 'chrony':
      ensure => installed,
    }
    service { 'chronyd':
      ensure => running,
      enable => true,
    }
  }

  if $manage_syslog and $facts['kernel'] == 'Linux' {
    package { 'rsyslog':
      ensure => installed,
    }
    service { 'rsyslog':
      ensure => running,
      enable => true,
    }
  }
}
