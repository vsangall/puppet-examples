# MIGRATION FROM PUPPET TO ANSIBLE

## Executive Summary

This repository contains a Puppet-based infrastructure configuration for a multi-tier application stack consisting of HAProxy load balancers, Python application servers with PostgreSQL databases, and Redis clusters. The migration to Ansible Automation Platform (AAP) will require converting Puppet modules, classes, and Hiera data structures to Ansible roles, playbooks, and variable files.

**Estimated Timeline:**
- Analysis and Planning: 1 week
- Core Module Migration: 3-4 weeks
- Testing and Validation: 2 weeks
- Documentation and Knowledge Transfer: 1 week
- Total: 7-8 weeks

**Complexity Assessment:** Medium to High
- Multiple interconnected modules with dependencies
- Hierarchical configuration data (Hiera)
- Secret management requirements
- Service orchestration with strict dependency chains

## Module Migration Plan

This repository contains Puppet modules that need individual migration planning:

### MODULE INVENTORY

- **profile_app_stack**:
    - Description: Python application stack with PostgreSQL database and systemd service management
    - Path: modules/profile_app_stack
    - Technology: Puppet
    - Key Features: Git-based application deployment, Python virtual environment, PostgreSQL database configuration, systemd service management, application monitoring

- **profile_haproxy**:
    - Description: HAProxy load balancer with multi-backend support, SSL termination, and statistics interface
    - Path: modules/profile_haproxy
    - Technology: Puppet
    - Key Features: HAProxy configuration management, SSL certificate handling, backend server configuration, firewall rules, statistics interface

- **profile_redis_cluster**:
    - Description: Redis cluster configuration with PuppetDB node discovery
    - Path: modules/profile_redis_cluster
    - Technology: Puppet
    - Key Features: Redis server installation and configuration, memory management, password authentication

- **Base Profile**:
    - Description: Common OS-level configuration for all nodes
    - Path: site/profile/manifests/base/base.pp
    - Technology: Puppet
    - Key Features: NTP configuration, syslog management, utility package installation

### Infrastructure Files

- `Puppetfile`: External module dependencies (puppetlabs-stdlib, puppetlabs-concat, puppetlabs-firewall, puppetlabs-vcsrepo, puppet-redis, puppetlabs-apt)
- `hiera.yaml`: Hierarchical data configuration with environment-specific overrides and encrypted data support
- `data/common.yaml`: Global default configurations
- `data/environment/*.yaml`: Environment-specific configuration overrides
- `site/role/manifests/*.pp`: Role definitions that compose profiles
- `site/profile/manifests/*/*.pp`: Profile implementations
- `Vagrantfile`: Development environment configuration using Ubuntu 24.04
- `vagrant-provision.sh`: Provisioning script for development environment

### Target Details

- **Operating System**: Ubuntu 24.04 (Noble Numbat) based on Vagrantfile and provisioning script
- **Virtual Machine Technology**: Vagrant with libvirt provider (2GB RAM, 2 CPUs)
- **Cloud Platform**: Not specified in the repository; appears to be designed for on-premises or generic cloud deployment

## Migration Approach

### Key Dependencies to Address

- **puppetlabs-stdlib (9.7.0)**: Replace with Ansible built-in filters and modules
- **puppetlabs-concat (9.0.2)**: Replace with Ansible template module and jinja2 templates
- **puppetlabs-firewall (8.1.3)**: Replace with Ansible `firewalld` or `ufw` modules
- **puppetlabs-vcsrepo (6.1.0)**: Replace with Ansible `git` module
- **puppet-redis (11.0.0)**: Replace with Ansible Redis role (community.general.redis or custom role)
- **puppetlabs-apt (9.4.0)**: Replace with Ansible `apt` module

### Security Considerations

- **Hiera eyaml**: The repository uses encrypted Hiera data with PKCS7 keys. Migration should use Ansible Vault for secrets management.
  - Migration approach: Convert eyaml encrypted values to Ansible Vault encrypted strings or files

- **Database credentials**: Database credentials are stored in Hiera and passed to the application.
  - Migration approach: Store credentials in Ansible Vault and pass to templates

- **Redis password**: Redis authentication password needs secure handling.
  - Migration approach: Store in Ansible Vault and reference in templates

- **SSL certificates**: HAProxy configuration includes SSL certificate paths.
  - Migration approach: Use Ansible Vault for certificate storage or implement certificate management with AAP

- **Vault/secrets management**:
  - profile_app_stack: 3 credentials (db_user, db_password, secret_key)
  - profile_haproxy: 2 credentials (stats_password, SSL certificates)
  - profile_redis_cluster: 1 credential (redis_password)

### Technical Challenges

- **PuppetDB queries**: The Redis cluster module uses PuppetDB queries for node discovery.
  - Mitigation: Replace with Ansible inventory groups or dynamic inventory

- **Strict dependency chains**: The application stack has strict ordering requirements.
  - Mitigation: Use Ansible handlers, meta dependencies, and task tags to maintain proper ordering

- **Hierarchical data**: Puppet uses Hiera with multiple levels of data hierarchy.
  - Mitigation: Implement Ansible variable precedence with group_vars, host_vars, and defaults

- **Custom functions**: The repository includes custom Puppet functions.
  - Mitigation: Implement as Jinja2 filters or Python callback plugins

- **Service verification**: The provisioning script includes service verification steps.
  - Mitigation: Implement Ansible handlers and service checks

### Migration Order

1. **Base Profile** (Low risk, foundation for other modules)
   - Convert common OS configurations
   - Implement NTP and syslog management

2. **HAProxy Profile** (Moderate complexity)
   - Convert HAProxy installation and configuration
   - Implement SSL certificate handling
   - Configure firewall rules

3. **Redis Cluster Profile** (Moderate complexity)
   - Convert Redis installation and configuration
   - Replace PuppetDB queries with inventory groups

4. **Application Stack Profile** (High complexity, dependencies)
   - Convert Python environment setup
   - Implement database configuration
   - Convert application deployment
   - Implement service management
   - Configure monitoring

### Assumptions

1. The target environment will continue to be Ubuntu 24.04 as specified in the Vagrantfile.
2. The application architecture (HAProxy + Python App + PostgreSQL + Redis) will remain unchanged.
3. The current role and profile pattern will be maintained in the Ansible structure.
4. PuppetDB functionality will be replaced with Ansible inventory or AAP inventory.
5. The eyaml encrypted data will be migrated to Ansible Vault.
6. The strict dependency chains in the application stack will be preserved.
7. The test environment using Vagrant will be maintained for development and testing.
8. The migration will not include changes to the application code or database schema.