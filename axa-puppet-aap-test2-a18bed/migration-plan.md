# MIGRATION FROM PUPPET TO ANSIBLE

## Executive Summary

This repository contains a Puppet-based infrastructure codebase that needs to be migrated to Ansible 2.6. The codebase follows the roles and profiles pattern and manages three main components: an application stack (Python/PostgreSQL), HAProxy load balancer, and Redis cluster. The migration complexity is moderate, with well-structured modules and clear dependencies. Estimated timeline: 3-4 weeks for a complete migration.

## Module Migration Plan

This repository contains Puppet modules that need individual migration planning:

### MODULE INVENTORY

- **profile_app_stack**:
    - Description: Python application stack with PostgreSQL database and systemd service management
    - Path: modules/profile_app_stack
    - Technology: Puppet
    - Key Features: Git repository deployment, Python virtual environment, PostgreSQL database configuration, systemd service management, application monitoring

- **profile_haproxy**:
    - Description: HAProxy load balancer with multi-backend support, SSL termination, and statistics interface
    - Path: modules/profile_haproxy
    - Technology: Puppet
    - Key Features: HAProxy configuration management, backend server configuration, SSL certificate management, firewall rules, statistics interface

- **profile_redis_cluster**:
    - Description: Redis cluster configuration with PuppetDB node discovery
    - Path: modules/profile_redis_cluster
    - Technology: Puppet
    - Key Features: Redis server installation, cluster configuration, memory management, password authentication

- **Base Profile**:
    - Description: Common OS-level configuration for all nodes
    - Path: site/profile/manifests/base/base.pp
    - Technology: Puppet
    - Key Features: NTP configuration (chrony), syslog management (rsyslog), utility package installation

### Infrastructure Files

- `Puppetfile`: Defines external module dependencies (puppetlabs-stdlib, puppetlabs-concat, puppetlabs-firewall, puppetlabs-vcsrepo, puppet-redis, puppetlabs-apt)
- `hiera.yaml`: Defines the Hiera configuration hierarchy with environment-specific and node-specific data
- `data/common.yaml`: Common configuration values for all environments
- `data/environment/*.yaml`: Environment-specific configuration overrides
- `Vagrantfile`: Defines a test environment using Ubuntu 24.04 with libvirt provider
- `vagrant-provision.sh`: Provisions the test environment with Puppet 8 and required modules
- `site/role/manifests/*.pp`: Role definitions that compose profiles
- `site/profile/manifests/*/*.pp`: Profile implementations that use the core modules

### Target Details

Based on the source configuration files:

- **Operating System**: Ubuntu 24.04 (based on Vagrantfile and module metadata)
- **Virtual Machine Technology**: libvirt (based on Vagrantfile configuration)
- **Cloud Platform**: Not specified (appears to be on-premises deployment)

## Migration Approach

### Key Dependencies to Address

- **puppetlabs-stdlib (9.7.0)**: Replace with Ansible built-in filters and modules
- **puppetlabs-concat (9.0.2)**: Replace with Ansible template module and blockinfile/lineinfile modules
- **puppetlabs-firewall (8.1.3)**: Replace with Ansible's ufw or iptables modules
- **puppetlabs-vcsrepo (6.1.0)**: Replace with Ansible's git module
- **puppet-redis (11.0.0)**: Replace with Ansible Redis role or community.general.redis module
- **puppetlabs-apt (9.4.0)**: Replace with Ansible's apt module

### Security Considerations

- **Hiera eyaml encryption**: Migrate encrypted data to Ansible Vault
  - Migration approach: Extract encrypted values from Hiera eyaml and store in Ansible Vault files
  
- **SSL/TLS certificates**: 
  - HAProxy SSL certificate and key paths need to be migrated
  - Migration approach: Use Ansible's copy module with no_log=True for sensitive files

- **Vault/secrets management**:
  - Credentials detected:
    - profile_app_stack: Database password, application secret key (2 credentials)
    - profile_haproxy: Stats password, SSL certificates (2 credentials)
    - profile_redis_cluster: Redis password (1 credential)
  - Migration approach: Store all credentials in Ansible Vault and reference them in playbooks

### Technical Challenges

- **PuppetDB queries**: The Redis cluster module uses PuppetDB for node discovery
  - Challenge: Ansible 2.6 doesn't have a direct equivalent to PuppetDB queries
  - Mitigation: Use Ansible inventory groups or dynamic inventory scripts to replace PuppetDB node discovery

- **Hiera data hierarchy**: Complex data lookup with environment-specific overrides
  - Challenge: Replicating the multi-level hierarchy in Ansible
  - Mitigation: Use Ansible group_vars and host_vars with proper inheritance, potentially with variable precedence rules

- **Strict dependency ordering**: The application stack has strict dependency chains
  - Challenge: Ensuring proper execution order in Ansible
  - Mitigation: Use Ansible handlers, meta tasks, and proper task dependencies

- **Ansible 2.6 limitations**: This is an older Ansible version with fewer modules
  - Challenge: Some modern Ansible features may not be available
  - Mitigation: Use available modules or write custom modules where needed

### Migration Order

1. **Base Profile** (Priority 1, low risk)
   - Simple OS-level configurations that other components depend on
   - Straightforward migration to Ansible tasks

2. **profile_haproxy** (Priority 2, moderate complexity)
   - Load balancer configuration with templates and firewall rules
   - Independent of other application components

3. **profile_redis_cluster** (Priority 3, moderate complexity)
   - Redis server configuration with clustering
   - Requires solving the PuppetDB query replacement

4. **profile_app_stack** (Priority 4, high complexity)
   - Most complex component with multiple dependencies
   - Requires database, application code, and service management

### Assumptions

1. The target Ansible version (2.6) is fixed and cannot be upgraded
2. The target OS (Ubuntu 24.04) will remain the same
3. The application deployment workflow (Git repository, Python virtual environment) will remain unchanged
4. The current network architecture and service discovery methods will be preserved
5. No changes to the application code or database schema are required
6. The HAProxy configuration structure will remain similar
7. Redis cluster configuration requirements will remain the same
8. The roles and profiles pattern will be adapted to Ansible roles and playbooks
9. Hiera data will be migrated to Ansible variable structures
10. PuppetDB queries will need alternative implementations in Ansible
11. The Vagrant-based testing approach will be preserved but adapted for Ansible