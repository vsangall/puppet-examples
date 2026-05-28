# Role: Redis cluster node
class role::redis_cluster {
  if $facts['kernel'].downcase == 'linux' {
    Exec {
      path => '/usr/bin:/bin:/usr/sbin:/sbin',
    }
  }

  include ::profile::base::base
  contain ::profile::cache::redis

  Class['::profile::base::base'] -> Class['::profile::cache::redis']
}
