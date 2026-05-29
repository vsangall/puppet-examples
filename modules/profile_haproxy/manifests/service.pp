# Manage HAProxy service lifecycle.
class profile_haproxy::service {

  $config_file = $profile_haproxy::config_file
  $config_dir  = $profile_haproxy::config_dir

  # Validate all config files before restart
  exec { 'haproxy_config_check':
    command     => "haproxy -c -f ${config_file} -f ${config_dir}/conf.d/",
    path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    refreshonly => true,
    subscribe   => File[$config_file],
  }

  # Drop-in override to load conf.d alongside main config
  $override_content = "[Service]\nExecStart=\nExecStart=/usr/sbin/haproxy -Ws -f ${config_file} -f ${config_dir}/conf.d/ -p /run/haproxy.pid\n"

  file { '/etc/systemd/system/haproxy.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/systemd/system/haproxy.service.d/override.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $override_content,
    notify  => Exec['haproxy_systemd_daemon_reload'],
  }

  exec { 'haproxy_systemd_daemon_reload':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
  }

  service { $profile_haproxy::service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package[$profile_haproxy::package_name],
      Exec['haproxy_config_check'],
      Exec['haproxy_systemd_daemon_reload'],
    ],
    subscribe  => File[$config_file],
  }

  # Log rotation
  $logrotate_content = "/var/log/haproxy/*.log {\n    daily\n    rotate 14\n    missingok\n    notifempty\n    compress\n    delaycompress\n    sharedscripts\n    postrotate\n        /bin/kill -HUP \$(cat /var/run/haproxy.pid 2>/dev/null) 2>/dev/null || true\n    endscript\n}\n"

  file { '/etc/logrotate.d/haproxy':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $logrotate_content,
  }
}
