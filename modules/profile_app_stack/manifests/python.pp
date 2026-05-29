# Python runtime and virtualenv setup.
class profile_app_stack::python {

  $python_version = lookup('profile_app_stack::python_version')
  $pip_packages   = lookup('profile_app_stack::pip_packages', Array[String], 'first', [])

  # Install Python and development packages
  $python_packages = [
    $python_version,
    "${python_version}-pip",
    "${python_version}-venv",
    "${python_version}-dev",
    'git',
    'build-essential',
  ]

  package { $python_packages:
    ensure => installed,
  }

  # Application user and group
  group { $profile_app_stack::app_group:
    ensure => present,
    system => true,
  }

  user { $profile_app_stack::app_user:
    ensure     => present,
    gid        => $profile_app_stack::app_group,
    home       => $profile_app_stack::app_dir,
    shell      => '/bin/bash',
    system     => true,
    managehome => false,
    require    => Group[$profile_app_stack::app_group],
  }

  # Log directory
  file { $profile_app_stack::log_dir:
    ensure => directory,
    owner  => $profile_app_stack::app_user,
    group  => $profile_app_stack::app_group,
    mode   => '0755',
  }

  # Log rotation
  file { "/etc/logrotate.d/${profile_app_stack::app_name}":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('profile_app_stack/logrotate.conf.erb'),
  }
}
