# Profile: HAProxy load balancer
# Thin wrapper that delegates to the profile_haproxy module.
class profile::loadbalancer::haproxy (
  Optional[String] $environment_name = fact('environment'),
) {
  class { 'profile_haproxy': }
}
