# Profile: Application stack (Python + PostgreSQL)
# Thin wrapper that delegates to the profile_app_stack module.
class profile::app::stack (
  Optional[String] $environment_name = fact('environment'),
) {
  class { 'profile_app_stack': }
}
