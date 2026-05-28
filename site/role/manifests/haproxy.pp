# Role: HAProxy load balancer node
# Composes base OS profile with HAProxy-specific profile.
class role::haproxy {
  if $facts['kernel'].downcase == 'linux' {
    Exec {
      path => '/usr/bin:/bin:/usr/sbin:/sbin',
    }
  }

  include ::profile::base::base
  contain ::profile::loadbalancer::haproxy

  Class['::profile::base::base'] -> Class['::profile::loadbalancer::haproxy']
}
