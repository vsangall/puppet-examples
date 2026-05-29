# Firewall configuration for HAProxy using UFW (Ubuntu).
class profile_haproxy::firewall {

  $firewall_provider = lookup('profile_haproxy::firewall_provider', String, 'first', 'ufw')

  if $firewall_provider == 'ufw' {
    package { 'ufw':
      ensure => installed,
    }

    exec { 'ufw_allow_http':
      command => 'ufw allow 80/tcp',
      unless  => 'ufw status | grep -q "80/tcp.*ALLOW"',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      require => Package['ufw'],
    }

    exec { 'ufw_allow_https':
      command => 'ufw allow 443/tcp',
      unless  => 'ufw status | grep -q "443/tcp.*ALLOW"',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      require => Package['ufw'],
    }

    if $profile_haproxy::stats_enabled {
      exec { 'ufw_allow_stats':
        command => "ufw allow ${profile_haproxy::stats_port}/tcp",
        unless  => "ufw status | grep -q '${profile_haproxy::stats_port}/tcp.*ALLOW'",
        path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
        require => Package['ufw'],
      }
    }

    exec { 'ufw_enable':
      command => 'ufw --force enable',
      unless  => 'ufw status | grep -q "Status: active"',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      require => Package['ufw'],
    }
  }
}
