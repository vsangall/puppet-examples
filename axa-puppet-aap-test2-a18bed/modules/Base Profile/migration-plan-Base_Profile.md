---
source-path: site/profile/manifests/base/base.pp
---

# Migration Plan: Base Profile

**TLDR**: This module provides basic OS-level configuration for all nodes, including system utilities, NTP time synchronization via chrony, and system logging via rsyslog. It serves as a foundation layer included by all roles in the infrastructure.

## Service Type and Instances

**Service Type**: Base System Configuration

**Configured Instances**:
- **chrony**: Network Time Protocol client
  - Location/Path: System service
  - Port/Socket: UDP 123 (outbound)
  - Key Config: Uses NTP servers from Hiera
- **rsyslog**: System logging service
  - Location/Path: System service
  - Port/Socket: UDP 514 (outbound to syslog server)
  - Key Config: Configured to send logs to syslog server defined in Hiera

## File Structure

```
site/profile/manifests/base/base.pp
data/common.yaml
data/environment/production.yaml
data/environment/staging.yaml
```

## Module Explanation

The module performs operations in this order:

1. **profile::base::base** (`site/profile/manifests/base/base.pp`):
   - Sets class parameters:
     - manage_ntp = true (default, can be overridden via Hiera)
     - manage_syslog = true (default, can be overridden via Hiera)
     - manage_utils = true (default, can be overridden via Hiera)
   - Conditional: if $manage_utils is true
     - Includes base_utils class (external class from /workspace/source/site/modules/common/base_utils/manifests/init.pp)
   - Conditional: if $manage_ntp is true AND $facts['kernel'] equals 'Linux'
     - Installs package: chrony (ensure: installed)
     - Manages service: chronyd (ensure: running, enable: true)
   - Conditional: if $manage_syslog is true AND $facts['kernel'] equals 'Linux'
     - Installs package: rsyslog (ensure: installed)
     - Manages service: rsyslog (ensure: running, enable: true)

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
- **Encrypted variables**: 0 variables that are encrypted

### Cross-Level Overrides

Variables defined at multiple Hiera levels:
- **ntp::servers**: defined at common.yaml, production.yaml, merge strategy: first
- **syslog::server**: defined at common.yaml, production.yaml, staging.yaml, merge strategy: first
- **syslog::facility**: defined at common.yaml, production.yaml, merge strategy: first

### Merge Strategy Notes

- Variables using `first` (default) - First value found wins, no merging
- The profile::base::base class uses the 'first' lookup method for its parameters

## Dependencies

**External module dependencies**: None directly referenced in this profile
**System package dependencies**: chrony, rsyslog
**Service dependencies**: None explicitly defined

### Dependency Details

This profile doesn't directly depend on external Puppet modules, but the overall control repo has these dependencies:
- **puppetlabs-stdlib**: Core Puppet functions, version 9.7.0
- **puppetlabs-concat**: File concatenation, version 9.0.2
- **puppetlabs-firewall**: Firewall management, version 8.1.3
- **puppetlabs-vcsrepo**: Version control repositories, version 6.1.0
- **puppet-redis**: Redis management, version 11.0.0
- **puppetlabs-apt**: APT package management, version 9.4.0

## Puppet Facts Used

- `$facts['kernel']` - Operating system kernel type (Linux, Windows, etc.) - Used to conditionally apply Linux-specific configurations

## Checks for the Migration

**Files to verify**: None directly managed by this profile
**Service endpoints to check**: 
- chronyd service status
- rsyslog service status
**Templates rendered**: None directly by this profile

## Pre-flight checks:
```bash
# Service status commands
systemctl status chronyd
systemctl status rsyslog

# Configuration validation commands
chronyc sources
# Check rsyslog configuration to ensure it's sending logs to the correct syslog server
```