class profile_redis_cluster (
  Integer $redis_port       = 6379,
  String  $redis_password   = 'CHANGEME',
  Integer $maxmemory_mb     = 2048,
  String  $maxmemory_policy = 'allkeys-lru',
) {

  $redis_nodes = puppetdb_query(
    "resources[certname] {
      type = 'Class' and
      title = 'Profile_redis_cluster'
    }"
  )

  contain profile_redis_cluster::install
}
