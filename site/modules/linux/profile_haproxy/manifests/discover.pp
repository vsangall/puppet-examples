# Discover backend servers via PuppetDB — used when backends are dynamic
# rather than statically defined in Hiera.
class profile_haproxy::discover {

  # Export this node's HAProxy membership so other nodes can discover it
  @@haproxy::balancermember { $facts['networking']['fqdn']:
    listening_service => 'webservers',
    server_names      => $facts['networking']['fqdn'],
    ipaddresses       => $facts['networking']['ip'],
    ports             => '8080',
    options           => 'check',
  }

  # Collect all exported balancer members for this cluster
  Haproxy::Balancermember <<| listening_service == 'webservers' |>>

  # Query PuppetDB for all application servers in this environment
  $app_servers = puppetdb_query(
    "resources[certname, parameters] {
      type = 'Class' and title = 'Profile::App_server'
      and certname in resources[certname] {
        type = 'Class' and title = 'Profile::Base'
        and parameters.environment = '${facts['puppet_environment']}'
      }
    }"
  )

  # Build dynamic backend list from PuppetDB query results
  $app_servers.each |$server| {
    $certname = $server['certname']
    $app_port = $server['parameters']['port']

    haproxy::balancermember { "api-${certname}":
      listening_service => 'api',
      server_names      => $certname,
      ipaddresses       => $certname,
      ports             => $app_port,
      options           => 'check inter 10s',
    }
  }
}
