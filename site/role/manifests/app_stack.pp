# Role: Application stack node (Python app + PostgreSQL)
class role::app_stack {
  if $facts['kernel'].downcase == 'linux' {
    Exec {
      path => '/usr/bin:/bin:/usr/sbin:/sbin',
    }
  }

  include ::profile::base::base
  contain ::profile::app::stack

  Class['::profile::base::base'] -> Class['::profile::app::stack']
}
