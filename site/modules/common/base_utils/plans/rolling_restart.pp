# Bolt plan: rolling restart of a service across targets.
plan base_utils::rolling_restart (
  TargetSpec $targets,
  String     $service,
  Integer    $delay_seconds = 30,
) {
  $target_list = get_targets($targets)

  $target_list.each |$target| {
    out::message("Restarting ${service} on ${target.name}")
    run_command("systemctl restart ${service}", $target)

    $check = run_task('base_utils::check_service', $target, service => $service)
    if $check.first['status'] != 'running' {
      fail_plan("Service ${service} failed to restart on ${target.name}")
    }

    out::message("Waiting ${delay_seconds}s before next target...")
    ctrl::sleep($delay_seconds)
  }

  out::message("Rolling restart complete for ${service}")
}
