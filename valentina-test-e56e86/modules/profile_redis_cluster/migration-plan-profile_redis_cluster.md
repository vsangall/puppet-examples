---
source-path: modules/profile_redis_cluster
---

# Migration Plan: profile_redis_cluster

**TLDR**: This module configures a Redis cluster with authentication, memory limits, and persistence settings. It uses PuppetDB to discover other Redis nodes and sets up Redis instances with appropriate configuration based on whether the node is a primary or replica.

## Service Type and Instances

**Service Type**: Cache (Redis)

**Configured Instances**:
- **Redis Server**: In-memory data structure store used as a database, cache, and message broker
  - Location/Path: /var/lib/redis
  - Port/Socket: 6379 (default, configurable)
  - Key Config: Authentication, memory limits (2048MB default), persistence (appendonly)

## File Structure

```
manifests/init.pp
manifests/install.pp
lib/facter/redis_role.rb
templates/redis.conf.erb
migration-dependencies/redis/manifests/init.pp
migration-dependencies/redis/manifests/preinstall.pp
migration-dependencies/redis/manifests/install.pp
migration-dependencies/redis/manifests/config.pp
migration-dependencies/redis/manifests/service.pp
migration-dependencies/redis/manifests/instance.pp
migration-dependencies/redis/manifests/ulimit.pp
migration-dependencies/redis/manifests/dnfmodule.pp
migration-dependencies/redis/templates/redis.conf.epp
migration-dependencies/redis/templates/service_templates/redis.service.epp
/workspace/source/site/role/manifests/redis_cluster.pp
/workspace/source/site/profile/manifests/cache/redis.pp
```

## Module Explanation

The module performs operations in this order:

1. **role::redis_cluster** (`/workspace/source/site/role/manifests/redis_cluster.pp`):
   - Includes profile::base::base class
   - Includes profile::cache::redis class
   - Sets ordering: Class['::profile::base::base'] -> Class['::profile::cache::redis']
   - Resources: None (orchestration only)

2. **profile::cache::redis** (`/workspace/source/site/profile/manifests/cache/redis.pp`):
   - Includes profile_redis_cluster class
   - Resources: None (orchestration only)

3. **profile_redis_cluster** (`manifests/init.pp`):
   - Sets class parameters: redis_port=6379, redis_password='CHANGEME', maxmemory_mb=2048, maxmemory_policy='allkeys-lru'
   - Executes PuppetDB query to find all nodes with the Profile_redis_cluster class
   - Contains profile_redis_cluster::install class
   - Resources: None (orchestration only)

4. **profile_redis_cluster::install** (`manifests/install.pp`):
   - Includes redis class with parameters:
     - bind='0.0.0.0'
     - port=$profile_redis_cluster::redis_port (6379)
     - requirepass=$profile_redis_cluster::redis_password ('CHANGEME')
     - maxmemory="${profile_redis_cluster::maxmemory_mb}mb" (2048mb)
     - appendonly=true
     - appendfsync='everysec'
     - manage_package=true
   - Resources: None (orchestration only)

5. **redis** (`migration-dependencies/redis/manifests/init.pp`):
   - Includes redis::preinstall class
   - Includes redis::install class
   - Includes redis::config class
   - Includes redis::service class
   - Sets ordering: preinstall -> install -> config ~> service (config changes notify service restart)
   - For each instance in $instances hash:
     - Creates redis::instance[default] resource
   - Resources: None (orchestration only)

6. **redis::preinstall** (`migration-dependencies/redis/manifests/preinstall.pp`):
   - Conditional: if $redis::manage_repo
     - Checks OS family and name to determine repository configuration
   - Resources: None (conditional repository management)

7. **redis::install** (`migration-dependencies/redis/manifests/install.pp`):
   - Conditional: if $redis::manage_package
     - Installs package: redis (name from $redis::package_name)
   - Conditional: if $redis::dnf_module_stream
     - Includes redis::dnfmodule class
       - **redis::dnfmodule** (`migration-dependencies/redis/manifests/dnfmodule.pp`):
         - Installs Redis DNF module with specified stream
         - Resources: package[redis dnf module] (1)
   - Resources: package[redis] (1)

8. **redis::config** (`migration-dependencies/redis/manifests/config.pp`):
   - Creates directory: $redis::config_dir (/etc/redis)
   - Creates directory: $redis::log_dir (/var/log/redis)
   - Creates directory: $redis::workdir (/var/lib/redis)
   - Conditional: if $redis::default_install
     - Creates redis::instance[default]
   - Conditional: if $redis::ulimit_managed
     - Includes redis::ulimit class
       - **redis::ulimit** (`migration-dependencies/redis/manifests/ulimit.pp`):
         - Conditional: if $redis::managed_by_cluster_manager
           - Creates file: /etc/security/limits.d/redis.conf
         - Creates file: /etc/systemd/system/${redis::service_name}.service.d/limit.conf
         - Resources: file (1-2)
   - Conditional: case $facts['os']['family']
     - Creates file: /etc/default/redis-server (for Debian)
   - Resources: file (3-4)

9. **redis::instance** (`migration-dependencies/redis/manifests/instance.pp`):
   - Creates Redis instance configuration
   - Renders configuration template
   - Sets up service for the instance
   - Resources: file, service (2)

10. **redis::service** (`migration-dependencies/redis/manifests/service.pp`):
    - Conditional: if $redis::service_manage
      - Manages service: redis-server (name from $redis::service_name)
        - ensure: running
        - enable: true
    - Resources: service (1)

The module uses a custom fact `redis_role` to determine if a Redis instance is a primary or replica:
- Checks if /etc/redis/conf.d/replica.conf exists and contains 'replicaof'
- Returns 'replica' if true, otherwise 'primary'

## Variables

**Variable Flow Summary**: 4 variables defined in the profile_redis_cluster class

### Variable Definitions

**profile_redis_cluster class parameters**:
- `profile_redis_cluster::redis_port`: `6379` (type: integer) → Migration note: Redis port configuration
- `profile_redis_cluster::redis_password`: `'CHANGEME'` (type: string) → Migration note: Redis authentication password, needs secure storage
- `profile_redis_cluster::maxmemory_mb`: `2048` (type: integer) → Migration note: Redis memory limit in MB
- `profile_redis_cluster::maxmemory_policy`: `'allkeys-lru'` (type: string) → Migration note: Redis eviction policy

**Redis module parameters** (set by profile_redis_cluster::install):
- `redis::bind`: `'0.0.0.0'` (type: string) → Migration note: Redis bind address
- `redis::port`: `$profile_redis_cluster::redis_port` (type: integer) → Migration note: Redis port
- `redis::requirepass`: `$profile_redis_cluster::redis_password` (type: string) → Migration note: Redis password
- `redis::maxmemory`: `"${profile_redis_cluster::maxmemory_mb}mb"` (type: string) → Migration note: Redis memory limit
- `redis::appendonly`: `true` (type: boolean) → Migration note: Redis persistence setting
- `redis::appendfsync`: `'everysec'` (type: string) → Migration note: Redis sync frequency
- `redis::manage_package`: `true` (type: boolean) → Migration note: Package management flag

### Variable Migration Summary

- **Common defaults**: 4 variables defined in the profile_redis_cluster class
- **Encrypted variables**: 1 variable (redis_password) that needs secure storage

### Cross-Level Overrides

No cross-level overrides detected in the Hiera data for Redis-specific variables.

### Merge Strategy Notes

No specific merge strategies detected for Redis-related variables.

## Custom Types and Providers

### Custom Fact: redis_role
- **Name**: redis_role
- **Purpose**: Determines if a Redis instance is configured as a primary or replica
- **Implementation**: Checks if /etc/redis/conf.d/replica.conf exists and contains 'replicaof'
- **Returns**: 'replica' if the node is configured as a replica, otherwise 'primary'
- **Platform constraints**: Linux only (confine kernel: 'Linux')
- **Migration notes**: This fact is used to determine the role of a Redis node in the cluster. In Ansible, this could be implemented as a custom fact or determined through inventory variables.

## Dependencies

**External module dependencies**:
- puppetlabs-stdlib (forge, version: 9.6.0)
- puppet-redis (forge, version: 11.0.0)
- puppetlabs-apt (forge, version: 9.4.0)

**System package dependencies**:
- redis (package name may vary by OS)

**Service dependencies**:
- redis-server

## Puppet Facts Used

- `$facts['kernel']` - Operating system kernel (Linux, Windows, etc.)
- `$facts['os']['family']` - Operating system family (RedHat, Debian, etc.)
- `$facts['os']['name']` - Operating system name
- `$facts['networking']['fqdn']` - Fully qualified domain name
- `$facts['environment']` - Current Puppet environment

## Template Conversion Notes

### redis.conf.erb
- **Variables used**:
  - `@facts['networking']['fqdn']` - Node's fully qualified domain name
  - `@redis_port` - Redis port number
  - `@redis_password` - Redis authentication password
  - `@maxmemory_mb` - Maximum memory in MB
  - `@maxmemory_policy` - Memory eviction policy
- **No complex Ruby logic blocks**
- **No conditional rendering**
- **No iterations**

### redis.conf.epp and redis.service.epp
- Used by redis::instance to generate instance-specific configuration and service files
- Variables include port, bind address, memory settings, and service parameters

## PuppetDB Dependencies

### PuppetDB Queries
- **Query**: `resources[certname] { type = 'Class' and title = 'Profile_redis_cluster' }`
- **Returns**: List of nodes with the Profile_redis_cluster class
- **Used for**: Discovering other Redis nodes in the cluster
- **Migration notes**: This query is used to discover other Redis nodes for clustering. In Ansible, this would need to be replaced with inventory-based discovery or an external data source.

## Checks for the Migration

**Files to verify**:
- /etc/redis/redis.conf
- /var/log/redis/redis-server.log
- /var/lib/redis
- /etc/systemd/system/redis-server.service.d/limit.conf
- /etc/security/limits.d/redis.conf (if managed by cluster manager)
- /etc/default/redis-server (on Debian systems)

**Service endpoints to check**:
- Redis server on port 6379 (or configured port)

**Templates rendered**:
- redis.conf.erb → /etc/redis/redis.conf (1 instance)
- redis.conf.epp → /etc/redis/redis.conf (1 instance per Redis instance)
- redis.service.epp → /etc/systemd/system/redis-server.service (1 instance per Redis instance)

## Pre-flight checks:
```bash
# Service status command
systemctl status redis-server

# Redis connectivity check
redis-cli -a <password> ping

# Redis configuration validation
redis-server --test-memory <bytes>

# Redis replication status
redis-cli -a <password> info replication

# Redis memory usage
redis-cli -a <password> info memory
```