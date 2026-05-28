# Defined type: create a directory with ownership and permissions.
define base_utils::create_dir (
  Stdlib::Absolutepath     $path  = $title,
  Optional[String]         $owner = undef,
  Optional[String]         $group = undef,
  Optional[Stdlib::Filemode] $mode  = undef,
) {

  exec { "mkdir_${path}":
    command => "mkdir -p ${path}",
    creates => $path,
    path    => '/usr/bin:/bin',
  }

  if $owner {
    exec { "chown_${path}":
      command     => "chown ${owner} ${path}",
      unless      => "stat -c '%U' ${path} | grep -q '^${owner}$'",
      path        => '/usr/bin:/bin',
      require     => Exec["mkdir_${path}"],
    }
  }

  if $group {
    exec { "chgrp_${path}":
      command     => "chgrp ${group} ${path}",
      unless      => "stat -c '%G' ${path} | grep -q '^${group}$'",
      path        => '/usr/bin:/bin',
      require     => Exec["mkdir_${path}"],
    }
  }

  if $mode {
    exec { "chmod_${path}":
      command     => "chmod ${mode} ${path}",
      path        => '/usr/bin:/bin',
      require     => Exec["mkdir_${path}"],
    }
  }
}
