# MIGRATION FROM PUPPET TO ANSIBLE

## Executive Summary

This migration plan outlines the conversion of a Puppet Enterprise codebase to Ansible Automation Platform (AAP) 2.6 for the AXA GO Project Atmos. The repository contains a well-structured Puppet codebase with three primary modules (profile_app_stack, profile_haproxy, profile_redis_cluster) following the roles and profiles pattern. The migration complexity is moderate, with clear separation of concerns and hierarchical data management through Hiera.

**Timeline Estimate:**
- Preparation Phase: 2-3 weeks
- MVP Build: 4-6 weeks
- Migration Factory: 12-18 months (for 20,000+ nodes)

## Module Migration Plan

This repository contains Puppet modules that need individual migration planning:

### MODULE INVENTORY

- **profile_app_stack**:
    - Description: Python application stack with PostgreSQL database, virtualenv management, and systemd service
    - Path: modules/profile_app_stack
    - Technology: Puppet
    - Key Features: Git-based deployment, Python virtualenv, database migrations, environment configuration

- **profile_haproxy**:
    - Description: HAProxy load balancer with multi-backend support, SSL termination, and statistics interface
    - Path: modules/profile_haproxy
    - Technology: Puppet
    - Key Features: Backend configuration, SSL management, firewall rules, service monitoring

- **profile_redis_cluster**:
    - Description: Redis cluster configuration with PuppetDB node discovery
    - Path: modules/profile_redis_cluster
    - Technology: Puppet
    - Key Features: Cluster configuration, memory management, password authentication

- **profile::base::base**:
    - Description: Base OS configuration applied to all nodes
    - Path: site/profile/manifests/base/base.pp
    - Technology: Puppet
    - Key Features: NTP (chrony), syslog (rsyslog), utility packages

### Infrastructure Files

- `Puppetfile`: External module dependencies (stdlib, concat, firewall, vcsrepo, redis, apt)
- `hiera.yaml`: Hierarchical data configuration with environment-specific overrides
- `data/common.yaml`: Common default values for all environments
- `data/environment/*.yaml`: Environment-specific configuration overrides
- `environment.conf`: Puppet environment configuration
- `Vagrantfile`: Local development environment configuration
- `vagrant-provision.sh`: Provisioning script for local development
- `x2a-rules/`: Migration rules and standards for Ansible conversion

### Target Details

- **Operating System**: Ubuntu 24.04 (based on operatingsystem_support in metadata.json files)
- **Virtual Machine Technology**: Not specified, but Vagrant is used for local development
- **Cloud Platform**: Not explicitly specified in the codebase

## Migration Approach

### Key Dependencies to Address

- **puppetlabs-stdlib (9.7.0)**: Replace with Ansible built-in filters and modules
- **puppetlabs-concat (9.0.2)**: Replace with Ansible template module and filters
- **puppetlabs-firewall (8.1.3)**: Replace with Ansible firewalld or iptables modules
- **puppetlabs-vcsrepo (6.1.0)**: Replace with Ansible git module
- **puppet-redis (11.0.0)**: Replace with Ansible Redis role from Galaxy
- **puppetlabs-apt (9.4.0)**: Replace with Ansible apt module

### Security Considerations

- **Hiera eyaml**: The repository uses encrypted Hiera data with PKCS7 keys. Migration requires implementing CyberArk JIT credential lookup as specified in requirements.
- **SSL/TLS Configuration**: HAProxy module contains SSL configuration that must be migrated with proper certificate handling.
- **Redis Password**: Redis cluster uses a password that should be migrated to use CyberArk JIT lookup.
- **Database Credentials**: Application stack contains database credentials that must be migrated to use CyberArk JIT lookup.
- **Vault/secrets management**: 
  - Encrypted eyaml data in Hiera (nodes/%{trusted.certname}.yaml)
  - Database credentials in profile_app_stack
  - Redis password in profile_redis_cluster
  - HAProxy stats password and SSL certificates
  - Application secret key in profile_app_stack

### Technical Challenges

- **PuppetDB Queries**: The Redis cluster module uses PuppetDB queries for node discovery. This needs to be replaced with Ansible inventory or dynamic inventory plugins.
- **Strict Dependency Chains**: The application stack uses strict dependency ordering that must be preserved in Ansible with proper handlers and notify mechanisms.
- **Distributed Variable Architecture**: Converting Hiera's hierarchical data model to the required four-tier variable architecture (Identity, Global, Team, Runtime) will require careful mapping and restructuring.
- **Push vs. Pull Model**: Transitioning from Puppet's agent-based pull model to Ansible's agentless push model requires rethinking execution flow and scheduling.
- **Event-Driven Ansible Integration**: Implementing EDA for zero-touch remediation will require additional automation beyond direct migration.

### Migration Order

1. **profile::base::base** (low risk, foundational): Basic OS configuration is a good starting point with minimal dependencies.
2. **profile_haproxy** (moderate complexity): Load balancer configuration with clear boundaries.
3. **profile_redis_cluster** (moderate complexity): Cache layer with PuppetDB dependency to solve.
4. **profile_app_stack** (high complexity): Application deployment with multiple dependencies and complex orchestration.

### Assumptions

1. All nodes are running Ubuntu 24.04 as specified in the metadata.json files.
2. The current Puppet implementation follows a pull model with agents installed on all nodes.
3. PuppetDB is currently used for node discovery in the Redis cluster.
4. The repository uses eyaml for encrypting sensitive data in Hiera.
5. The application is a Python application with PostgreSQL database.
6. The migration will preserve the roles and profiles pattern but adapt it to Ansible's structure.
7. No custom facts or functions beyond those visible in the repository are in use.
8. The migration will need to address the shift from pull to push model.

## Detailed Migration Strategy

### 1. Preparation Phase

#### Repository Structure Setup

Create the three-tier repository structure as required:

```
ansible-project/
├── aap-cac/                # AAP Configuration as Code
├── team-repos/             # Functional playbooks and roles
│   ├── base/               # Base OS configuration
│   ├── haproxy/            # HAProxy configuration
│   ├── redis/              # Redis cluster configuration
│   └── app-stack/          # Application stack
└── variable-repo/          # Tiered inventory data
    ├── identity/           # Identity tier (from CMDB)
    ├── global/             # Global tier (regional/provider defaults)
    ├── team/               # Team tier (application tuning)
    └── runtime/            # Runtime tier (extra vars)
```

#### Variable Structure Mapping

Map Hiera hierarchy to the four-tier variable model:

1. **Identity Tier**: Map node-specific data from `data/nodes/%{trusted.certname}.yaml`
2. **Global Tier**: Map environment data from `data/environment/%{facts.environment}.yaml`
3. **Team Tier**: Map module-specific data from module Hiera data
4. **Runtime Tier**: Define variables that should be passed as extra vars

### 2. MVP Build Phase

#### Base Role Development

1. Convert `profile::base::base` to an Ansible role:
   - Create role structure with tasks, handlers, defaults
   - Implement chrony configuration
   - Implement rsyslog configuration
   - Implement utility package installation

#### HAProxy Role Development

1. Convert `profile_haproxy` to an Ansible role:
   - Create templates for HAProxy configuration
   - Implement SSL certificate handling via CyberArk lookups
   - Configure firewall rules
   - Set up service management and health checks

#### Redis Cluster Role Development

1. Convert `profile_redis_cluster` to an Ansible role:
   - Replace PuppetDB queries with Ansible inventory groups
   - Implement cluster configuration
   - Configure memory management
   - Set up password authentication via CyberArk lookups

#### Application Stack Role Development

1. Convert `profile_app_stack` to an Ansible role:
   - Implement Python virtualenv management
   - Set up Git-based deployment
   - Configure database connections via CyberArk lookups
   - Manage systemd service
   - Implement application monitoring

### 3. Migration Factory Phase

#### Playbook Development

1. Create playbooks that combine roles:
   - `base.yml`: Apply base configuration to all nodes
   - `haproxy.yml`: Configure HAProxy load balancers
   - `redis.yml`: Set up Redis cluster nodes
   - `app-stack.yml`: Deploy application stack

#### Integration with Event-Driven Ansible

1. Develop EDA rulebooks for zero-touch remediation:
   - Service failure detection and recovery
   - Performance threshold monitoring
   - Security event response

#### Testing and Validation

1. Implement testing strategy:
   - Molecule tests for individual roles
   - Integration tests for combined playbooks
   - Validation against target environments

#### Phased Rollout

1. Develop migration waves based on environment and criticality:
   - Development environments first
   - Non-production testing environments
   - Staging environments
   - Production environments (by service criticality)

## Distributed Variable Architecture Implementation

### Identity Tier (Source: Postgres/CMDB)

```yaml
# host_vars/app-server-01.yml (generated from CMDB)
node_id: app-server-01
node_role: app_stack
datacenter: dc1
environment: production
```

### Global Tier (Source: Inventory Repo)

```yaml
# global/regions/emea.yml
ntp_servers:
  - ntp1.emea.internal
  - ntp2.emea.internal

syslog_server: syslog.emea.internal
```

### Team Tier (Source: Product Repo group_vars)

```yaml
# team/app_stack/vars.yml
app_name: example-app
app_port: 8000
worker_count: 4
worker_class: uvicorn.workers.UvicornWorker
max_requests: 1000
graceful_timeout: 30
log_level: info
```

### Runtime Tier (Source: AAP Extra Vars)

```yaml
# Set at runtime via AAP
deployment_version: v1.2.3
maintenance_mode: false
debug_enabled: false
```

## Secret Management Strategy

Replace all hardcoded secrets with CyberArk JIT lookups:

```yaml
# Example of CyberArk JIT lookup for database credentials
db_user: "{{ lookup('cyberark.conjur.conjur_variable', 'app/db/username') }}"
db_password: "{{ lookup('cyberark.conjur.conjur_variable', 'app/db/password') }}"
```

## Conclusion

This migration plan provides a comprehensive roadmap for converting the existing Puppet codebase to Ansible Automation Platform 2.6. By following the structured approach outlined in this document, the migration can be executed in a phased manner while ensuring alignment with the required architectural principles, including the distributed variable architecture, inner source model, and zero-secret policy.

The plan addresses the specific requirements of the AXA GO Project Atmos, including the decommissioning of 20,000+ Puppet nodes by the end of 2026, prioritizing Day 2 operations, and implementing Event-Driven Ansible for zero-touch remediation.