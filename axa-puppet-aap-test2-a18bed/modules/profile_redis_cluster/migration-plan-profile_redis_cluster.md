---
source-path: modules/profile_redis_cluster
---

# Migration Plan: profile_redis_cluster

**TLDR**: This module configures a Redis server or cluster with customizable memory, port, and authentication settings. It uses the redis module to install and configure Redis instances, with support for determining node roles (primary/replica) through a custom fact.

## Service Type and Instances

**Service Type**: Cache (Redis)

**Configured Instances**:
- **Redis Server**: In-memory data structure store
  - Location/Path: /var/lib/redis
  - Port/Socket: 6379 (default, configurable)
  - Key Config: maxmemory=2048mb, maxmemory-policy=allkeys-lru, appendonly=true

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
migration-dependencies/redis/manifests/params.pp
migration-dependencies/redis/manifests/ulimit.pp
migration-dependencies/redis/manifests/dnfmodule.pp
migration-dependencies/redis/templates/redis.conf.epp
migration-dependencies/redis/templates/service_templates/redis.service.epp
```

## Module Explanation

The module performs operations in this order:

1. **profile_redis_cluster** (`manifests/init.pp`):
   - Sets class parameters: redis_port=6379, redis_password='CHANGEME', maxmemory_mb=2048, maxmemory_policy='allkeys-lru'
   - Queries PuppetDB for all nodes with the Profile_redis_cluster class to identify cluster members
   - Contains profile_redis_cluster::install class
   - Resources: None (orchestration only)

2. **profile_redis_cluster::install** (`manifests/install.pp`):
   - Includes redis class from dependency module with parameters:
     - bind='0.0.0.0'
     - port=$profile_redis_cluster::redis_port (6379)
     - requirepass=$profile_redis_cluster::redis_password ('CHANGEME')
     - maxmemory="${profile_redis_cluster::maxmemory_mb}mb" (2048mb)
     - appendonly=true
     - appendfsync='everysec'
     - manage_package=true
   - Resources: None (delegates to redis module)
   
3. **redis** (`migration-dependencies/redis/manifests/init.pp`):
   - Contains redis::preinstall class
   - Contains redis::install class
   - Contains redis::config class
   - Contains redis::service class
   - Sets ordering: preinstall -> install -> config ~> service (config changes notify service restart)
   - Resources: None (orchestration only)
   
4. **redis::preinstall** (`migration-dependencies/redis/manifests/preinstall.pp`):
   - Conditionally manages repository if $redis::manage_repo is true (not set in this case)
   - Uses OS facts to determine repository configuration
   - Resources: None (not used in this configuration)
   
5. **redis::install** (`migration-dependencies/redis/manifests/install.pp`):
   - Installs package: redis (package name from $redis::package_name)
   - Conditionally manages DNF module if $redis::dnf_module_stream is set (not set in this case)
   - Resources: package (1)
   
6. **redis::config** (`migration-dependencies/redis/manifests/config.pp`):
   - Creates directory: $redis::config_dir (/etc/redis) with mode 0755
   - Creates directory: $redis::log_dir (/var/log/redis) with mode 0755
   - Creates directory: $redis::workdir (/var/lib/redis) with mode 0750
   - Conditionally creates default Redis instance if $redis::default_install is true (default: true):
     - Creates Redis instance via redis::instance['default'] defined type
   - Conditionally manages ulimit if $redis::ulimit_managed is true (default: true):
     - **redis::ulimit** (`migration-dependencies/redis/manifests/ulimit.pp`):
       - Creates systemd override directory: /etc/systemd/system/${redis::service_name}.service.d
       - Deploys limit.conf template to set file descriptor limits:
         - Template: service_templates/limit.conf.epp → /etc/systemd/system/${redis::service_name}.service.d/limit.conf (mode: 0644)
         - Sets: LimitNOFILE=$redis::ulimit (65536)
   - Conditionally creates OS-specific configuration files based on $facts['os']['family']
     - For Debian: Creates /etc/default/redis-server with Redis configuration
   - Resources: file (3), redis::instance (1)
   - **notifies**: Changes to configuration files notify service[redis-server] to restart
   
7. **redis::service** (`migration-dependencies/redis/manifests/service.pp`):
   - Conditionally manages service if $redis::service_manage is true (default: true)
   - Manages service: redis-server (from $redis::service_name)
     - ensure: running
     - enable: true
   - Resources: service (1)

8. **Custom Fact: redis_role** (`lib/facter/redis_role.rb`):
   - Determines if Redis instance is a primary or replica
   - Checks for 'replicaof' directive in /etc/redis/conf.d/replica.conf
   - Returns 'replica' if directive is found, otherwise 'primary'
   - Confined to Linux systems only

## Variables

**Variable Flow Summary**: 4 variables defined in profile_redis_cluster class

### Variable Definitions

**profile_redis_cluster class parameters**:
- `profile_redis_cluster::redis_port`: `6379` (type: Integer)
- `profile_redis_cluster::redis_password`: `'CHANGEME'` (type: String)
- `profile_redis_cluster::maxmemory_mb`: `2048` (type: Integer)
- `profile_redis_cluster::maxmemory_policy`: `'allkeys-lru'` (type: String)

**redis module parameters** (subset of relevant ones):
- `redis::bind`: `'0.0.0.0'` (type: String)
- `redis::port`: `6379` (type: Integer)
- `redis::requirepass`: `'CHANGEME'` (type: String)
- `redis::maxmemory`: `'2048mb'` (type: String)
- `redis::appendonly`: `true` (type: Boolean)
- `redis::appendfsync`: `'everysec'` (type: String)
- `redis::manage_package`: `true` (type: Boolean)

### Variable Migration Summary

- **Common defaults**: 4 variables defined in profile_redis_cluster class
- **OS-specific variables**: None explicitly defined
- **Environment-specific variables**: None explicitly defined
- **Host-specific variables**: None explicitly defined
- **Encrypted variables**: None explicitly encrypted, but redis_password should be treated as sensitive

### Cross-Level Overrides

No variables are defined at multiple Hiera levels.

### Merge Strategy Notes

No merge strategies are explicitly defined for variables in this module.

## Custom Types and Providers

### Custom Fact: redis_role
- **Name**: redis_role
- **Purpose**: Determines if a Redis instance is configured as a primary or replica
- **Implementation**: Checks for 'replicaof' directive in /etc/redis/conf.d/replica.conf
- **Returns**: 'replica' if directive is found, otherwise 'primary'
- **Platform constraints**: Linux only (confine kernel: 'Linux')
- **Migration notes**: This fact is used to determine the role of a Redis node in a cluster. In Ansible, this could be implemented as a custom fact or by directly checking the configuration file in tasks.

## Dependencies

**External module dependencies**:
- puppetlabs-stdlib (forge, version: 9.6.0)
- puppet-redis (forge, version: 11.0.0)
- puppetlabs-apt (forge, version: 9.4.0)

**System package dependencies**:
- redis (package name may vary by OS)

**Service dependencies**:
- redis-server service

## Puppet Facts Used

- `$facts['kernel']` - Operating system kernel (Linux, Windows, etc.)
- `$facts['os']['family']` - Operating system family (RedHat, Debian, etc.)
- `$facts['os']['name']` - Operating system name
- `$facts['networking']['fqdn']` - Fully qualified domain name (used in template)

## Template Conversion Notes

### redis.conf.erb
- **Variables used**:
  - `@facts['networking']['fqdn']` - Node's fully qualified domain name
  - `@redis_port` - Redis port number
  - `@redis_password` - Redis authentication password
  - `@maxmemory_mb` - Maximum memory in MB
  - `@maxmemory_policy` - Memory eviction policy
- **Template content**: Standard Redis configuration with bind address, port, authentication, persistence settings, and memory limits

## PuppetDB Dependencies

### PuppetDB Queries
- **Query**: `resources[certname] { type = 'Class' and title = 'Profile_redis_cluster' }`
- **Returns**: List of nodes with the Profile_redis_cluster class
- **Used for**: Identifying all Redis cluster members
- **Migration notes**: In Ansible, this would require an inventory or external source to identify cluster members

## Checks for the Migration

**Files to verify**:
- /etc/redis/redis.conf
- /var/log/redis/redis-server.log

**Service endpoints to check**:
- TCP port 6379 (or custom port if configured)
- Unix socket /var/run/redis/redis.sock

**Templates rendered**:
- redis.conf.erb → /etc/redis/redis.conf (1 instance per node)

## Pre-flight checks:
```bash
# Service status command
systemctl status redis-server

# Redis connectivity check
redis-cli -a <password> ping

# Redis configuration test
redis-server --test-memory <bytes>
```