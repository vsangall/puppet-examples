# Base utilities module providing common helper types and functions.
class base_utils (
  Boolean $manage_motd    = lookup('base_utils::manage_motd', Boolean, 'first', true),
  String  $motd_template  = lookup('base_utils::motd_template', String, 'first', 'base_utils/motd.erb'),
  Array[String] $utility_packages = lookup('base_utils::utility_packages', Array[String], 'first', []),
) {

  if $manage_motd {
    file { '/etc/motd':
      ensure  => file,
      content => template($motd_template),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }
  }

  $utility_packages.each |String $pkg| {
    package { $pkg:
      ensure => installed,
    }
  }
}
