# Profile: Redis cluster
# Thin wrapper that delegates to the profile_redis_cluster module.
class profile::cache::redis (
  Optional[String] $environment_name = fact('environment'),
) {
  class { 'profile_redis_cluster': }
}
