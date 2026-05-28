# Bolt plan: run health checks across target nodes.
plan base_utils::health_check (
  TargetSpec $targets,
  String     $service = 'sshd',
) {
  $results = run_task('base_utils::check_service', $targets, service => $service)

  $failed = $results.filter |$r| { $r['status'] != 'running' }

  if $failed.empty {
    out::message("All targets healthy: ${service} is running")
  } else {
    $failed_hosts = $failed.map |$r| { $r.target.name }
    out::message("UNHEALTHY targets: ${failed_hosts.join(', ')}")
  }

  return $results
}
