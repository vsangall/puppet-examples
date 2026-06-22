---
source-path: site/profile/manifests/base/base.pp
---

# Migration Plan: Base Profile

**TLDR**: This module provides basic OS-level configuration for all nodes, managing NTP time synchronization via chrony, system logging via rsyslog, and optionally including a base utilities class. It's a foundational profile included by all roles to ensure consistent system configuration.

## Service Type and Instances

**Service Type**: System Configuration (Base OS Profile)

**Configured Instances**:
- **chrony**: Time synchronization service
  - Location/Path: System service
  - Port/Socket: UDP 123 (standard NTP port)
  - Key Config: NTP servers from Hiera
- **rsyslog**: System logging service
  - Location/Path: System service
  - Port/Socket: UDP/TCP 514 (standard syslog port)
  - Key Config: Log server and facility from Hiera

## File Structure

```
site/profile/manifests/base/base.pp
data/common.yaml
data/environment/production.yaml
data/environment/staging.yaml
site/role/manifests/redis_cluster.pp
site/profile/manifests/cache/redis.pp
site/modules/linux/profile_redis_cluster/manifests/init.pp
site/modules/common/base_utils/manifests/init.pp
```

## Module Explanation

The module performs operations in this order:

1. **role::redis_cluster** (`site/role/manifests/redis_cluster.pp`):
   - Includes profile::base::base class
   - Includes profile::cache::redis class
   - Sets ordering constraint: Class['::profile::base::base'] -> Class['::profile::cache::redis']
   - Contains conditional Exec resource

2. **profile::base::base** (`site/profile/manifests/base/base.pp`):
   - Sets class parameters from Hiera lookups:
     - manage_ntp = true (default, can be overridden in Hiera)
     - manage_syslog = true (default, can be overridden in Hiera)
     - manage_utils = true (default, can be overridden in Hiera)
   - Conditional: if $manage_utils is true
     - Includes base_utils class (external class from common module)
   - Conditional: if $manage_ntp and $facts['kernel'] == 'Linux'
     - Installs package: chrony (ensure: installed)
     - Manages service: chronyd (ensure: running, enable: true)
   - Conditional: if $manage_syslog and $facts['kernel'] == 'Linux'
     - Installs package: rsyslog (ensure: installed)
     - Manages service: rsyslog (ensure: running, enable: true)

3. **profile::cache::redis** (`site/profile/manifests/cache/redis.pp`):
   - Included by role::redis_cluster
   - Depends on profile::base::base (ordering constraint)

## Variables

**Variable Flow Summary**: 6 variables across 3 Hiera levels

### Variable Definitions

**common.yaml (defaults)** → Migration note: Base defaults for all nodes
- `ntp::servers`: `[0.pool.ntp.org, 1.pool.ntp.org]` (type: array)
- `ssh::client_alive_interval`: `300` (type: integer)
- `ssh::permit_root_login`: `false` (type: boolean)
- `syslog::server`: `127.0.0.1` (type: string)
- `syslog::facility`: `local0` (type: string)

**environment/production.yaml (environment overrides)** → Migration note: Production environment-specific variables
- `ntp::servers`: `[ntp1.prod.internal, ntp2.prod.internal]` (type: array)
- `syslog::server`: `syslog.prod.internal` (type: string)
- `syslog::facility`: `local1` (type: string)

**environment/staging.yaml (environment overrides)** → Migration note: Staging environment-specific variables
- `syslog::server`: `syslog.staging.internal` (type: string)

### Variable Migration Summary

- **Common defaults**: 5 variables from common.yaml (base configuration for all nodes)
- **Environment-specific variables**: 4 variables that vary by deployment environment (production, staging)
- **Host-specific variables**: 0 variables for individual host overrides
- **Encrypted variables**: 0 variables that are encrypted (eyaml) and need secure storage

### Cross-Level Overrides

Variables defined at multiple Hiera levels:
- **ntp::servers**: defined at common.yaml, production.yaml, merge strategy: first
- **syslog::server**: defined at common.yaml, production.yaml, staging.yaml, merge strategy: first
- **syslog::facility**: defined at common.yaml, production.yaml, merge strategy: first

### Merge Strategy Notes

- Variables using `first` (default) - First value found wins, no merging

## Dependencies

**External module dependencies**: 
- base_utils (from common module)
- profile_redis_cluster (from linux module)

**System package dependencies**: chrony, rsyslog
**Service dependencies**: None explicitly defined

## Puppet Facts Used

- `$facts['kernel']` - Operating system kernel (Linux, Windows, etc.) - Used to conditionally apply Linux-specific configurations

## Checks for the Migration

**Files to verify**: None directly managed by this profile
**Service endpoints to check**: 
- chronyd service status
- rsyslog service status

## Pre-flight checks:
```bash
# Check chrony service
systemctl status chronyd
chronyc sources

# Check rsyslog service
systemctl status rsyslog
grep -r "syslog.*.internal" /etc/rsyslog*
```