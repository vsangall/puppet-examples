---
source-path: modules/profile_app_stack
---

# Migration Plan: profile_app_stack

**TLDR**: This module deploys and manages a Python web application with PostgreSQL database support. It handles the complete application lifecycle including Python environment setup, database provisioning, application deployment from Git, service management via systemd, and monitoring integration. The module follows a strict dependency chain and supports different configurations for production and staging environments.

## Service Type and Instances

**Service Type**: Application Stack (Python Web Application + PostgreSQL Database)

**Configured Instances**:
- **myapp-api**: Python web application
  - Location/Path: /opt/myapp-api
  - Port/Socket: 8000
  - Key Config: Uses gunicorn with uvicorn workers, PostgreSQL database backend

## File Structure

```
modules/profile_app_stack/data/common.yaml
modules/profile_app_stack/data/environment/production.yaml
modules/profile_app_stack/data/environment/staging.yaml
modules/profile_app_stack/manifests/app.pp
modules/profile_app_stack/manifests/database.pp
modules/profile_app_stack/manifests/init.pp
modules/profile_app_stack/manifests/monitoring.pp
modules/profile_app_stack/manifests/python.pp
modules/profile_app_stack/manifests/service.pp
modules/profile_app_stack/templates/app.env.erb
modules/profile_app_stack/templates/app.service.epp
modules/profile_app_stack/templates/logrotate.conf.erb
```

## Module Explanation

The module performs operations in this order:

1. **profile_app_stack** (`manifests/init.pp`):
   - Sets class parameters from Hiera: app_name=myapp-api, app_repo=https://github.com/example-org/myapp-api.git, app_revision=main (overridden in environments), app_port=8000, app_dir=/opt/myapp-api, app_user=myapp, app_group=myapp, db_host=localhost (overridden in environments), db_port=5432, db_name=myapp_db, db_user=myapp_app, db_password=(encrypted), worker_count=2 (overridden in environments), worker_class=uvicorn.workers.UvicornWorker, max_requests=1000 (overridden in environments), graceful_timeout=30, log_dir=/var/log/myapp-api, log_level=info (overridden in environments), secret_key=(encrypted in production, plaintext in staging)
   - Contains profile_app_stack::python
   - Contains profile_app_stack::database
   - Contains profile_app_stack::app
   - Contains profile_app_stack::service
   - Contains profile_app_stack::monitoring
   - Sets ordering: python -> database -> app ~> service -> monitoring (app changes notify service restart)
   - Resources: None (orchestration only)

2. **profile_app_stack::python** (`manifests/python.pp`):
   - Sets variables from Hiera: python_version=python3, pip_packages=['uvicorn', 'gunicorn', 'psycopg2-binary']
   - Installs packages: python3, python3-pip, python3-venv, python3-dev, git, build-essential
   - Creates system group: myapp (system=true)
   - Creates system user: myapp (gid=myapp, home=/opt/myapp-api, shell=/bin/bash, system=true)
   - Creates log directory: /var/log/myapp-api (owner=myapp, group=myapp, mode=0755)
   - Deploys logrotate configuration:
     - Template: logrotate.conf.erb → /etc/logrotate.d/myapp-api (owner=root, group=root, mode=0644)
     - Sets: log_dir=/var/log/myapp-api, log_rotate_count=7, log_max_size=100M, app_name=myapp-api
   - Resources: package (6), group (1), user (1), file (2)

3. **profile_app_stack::database** (`manifests/database.pp`):
   - Conditional: If db_host is 'localhost' (true in staging, false in production):
     - Installs packages: postgresql, postgresql-contrib, libpq-dev
     - Manages service: postgresql (ensure=running, enable=true)
     - Creates database user via exec: myapp_app with password from Hiera (encrypted)
     - Creates database via exec: myapp_db with owner myapp_app
     - Grants privileges via exec: ALL PRIVILEGES on myapp_db to myapp_app
   - Installs package: cron
   - Deploys backup script:
     - File: /usr/local/bin/db-backup.sh (source=puppet:///modules/profile_app_stack/backup.sh, owner=root, group=myapp, mode=0750)
   - Creates cron job: database_backup (command="/usr/local/bin/db-backup.sh myapp_db $db_host", user=root, hour=2, minute=30)
   - Resources: package (4), service (1), exec (3), file (1), cron (1)

4. **profile_app_stack::app** (`manifests/app.pp`):
   - Sets variable from Hiera: python_version=python3
   - Deploys application from Git:
     - vcsrepo: /opt/myapp-api (provider=git, source=https://github.com/example-org/myapp-api.git, revision=main in staging, v2.4.1 in production, owner=myapp, group=myapp)
   - Creates Python virtual environment:
     - exec: create_app_venv (command="python3 -m venv /opt/myapp-api/venv", creates=/opt/myapp-api/venv/bin/activate, user=myapp)
   - Installs Python requirements:
     - exec: install_requirements (command="/opt/myapp-api/venv/bin/pip install -r /opt/myapp-api/requirements.txt", user=myapp, unless="pip freeze | diff - requirements.txt")
   - Installs additional pip packages:
     - exec: install_pip_uvicorn (command="/opt/myapp-api/venv/bin/pip install uvicorn", unless="pip show uvicorn", user=myapp)
     - exec: install_pip_gunicorn (command="/opt/myapp-api/venv/bin/pip install gunicorn", unless="pip show gunicorn", user=myapp)
     - exec: install_pip_psycopg2-binary (command="/opt/myapp-api/venv/bin/pip install psycopg2-binary", unless="pip show psycopg2-binary", user=myapp)
   - Deploys environment file:
     - Template: app.env.erb → /opt/myapp-api/.env (owner=myapp, group=myapp, mode=0600)
     - Sets: DATABASE_URL, APP_NAME=myapp-api, APP_PORT=8000, SECRET_KEY=(encrypted in production, plaintext in staging), LOG_LEVEL=(warning in production, debug in staging), LOG_DIR=/var/log/myapp-api, WORKERS=(8 in production, 1 in staging)
     - Conditional: If environment is production:
       - Sets: DEBUG=false, ALLOWED_HOSTS=*, CORS_ORIGINS=https://app.example.com,https://admin.example.com
     - Otherwise:
       - Sets: DEBUG=true, ALLOWED_HOSTS=*, CORS_ORIGINS=*
   - Deploys health check script:
     - File: /usr/local/bin/app-healthcheck.sh (source=puppet:///modules/profile_app_stack/healthcheck.sh, owner=root, group=root, mode=0755)
   - Runs database migrations:
     - exec: run_db_migrations (command="/opt/myapp-api/venv/bin/python -m alembic upgrade head", cwd=/opt/myapp-api, user=myapp, environment=["DATABASE_URL=${db_url}"], refreshonly=true, onlyif="test -f alembic.ini && test -f migrations/env.py")
   - Resources: vcsrepo (1), exec (5), file (2)
   - **notifies**: vcsrepo[/opt/myapp-api] ~> exec[run_db_migrations], exec[install_requirements] ~> Class[profile_app_stack::service], file[/opt/myapp-api/.env] ~> Class[profile_app_stack::service]

5. **profile_app_stack::service** (`manifests/service.pp`):
   - Deploys systemd service unit:
     - Template: app.service.epp → /etc/systemd/system/myapp-api.service (owner=root, group=root, mode=0644)
     - Sets: app_name=myapp-api, app_dir=/opt/myapp-api, app_user=myapp, app_group=myapp, app_port=8000, worker_count=(8 in production, 1 in staging), worker_class=uvicorn.workers.UvicornWorker, max_requests=(5000 in production, 100 in staging), graceful_timeout=30, log_dir=/var/log/myapp-api, log_level=(warning in production, debug in staging)
   - Reloads systemd daemon:
     - exec: app_stack_systemd_daemon_reload (command="systemctl daemon-reload", refreshonly=true)
   - Manages service: myapp-api (ensure=running, enable=true)
   - Resources: file (1), exec (1), service (1)
   - **notifies**: file[/etc/systemd/system/myapp-api.service] ~> exec[app_stack_systemd_daemon_reload]

6. **profile_app_stack::monitoring** (`manifests/monitoring.pp`):
   - Defines virtual resources (not realized by default):
     - @package: prometheus-node-exporter (ensure=installed)
     - @service: prometheus-node-exporter (ensure=running, enable=true)
     - @package: prometheus-pushgateway (ensure=installed)
     - @cron: push_app_metrics (command="/usr/local/bin/app-healthcheck.sh --push-metrics", user=myapp, minute="*/5")
   - Conditional: If environment is production:
     - Realizes virtual resources: package[prometheus-node-exporter], service[prometheus-node-exporter], package[prometheus-pushgateway], cron[push_app_metrics]
   - Creates health check cron job (always active):
     - cron: app_health_check (command="/usr/local/bin/app-healthcheck.sh http://localhost:8000/health", user=root, minute="*/2")
   - Resources: cron (1), virtual resources (4) - only realized in production
   - **fact**: $facts['environment']

## Variables

**Variable Flow Summary**: 19 variables across 3 Hiera levels (common, production, staging)

### Variable Definitions

**common.yaml (defaults)** → Migration note: Base defaults for all nodes
- `profile_app_stack::app_name`: `myapp-api` (type: string)
- `profile_app_stack::app_repo`: `https://github.com/example-org/myapp-api.git` (type: string)
- `profile_app_stack::app_revision`: `main` (type: string)
- `profile_app_stack::app_port`: `8000` (type: integer)
- `profile_app_stack::app_dir`: `/opt/myapp-api` (type: string)
- `profile_app_stack::app_user`: `myapp` (type: string)
- `profile_app_stack::app_group`: `myapp` (type: string)
- `profile_app_stack::python_version`: `python3` (type: string)
- `profile_app_stack::pip_packages`: (type: array)
  ```yaml
  - uvicorn
  - gunicorn
  - psycopg2-binary
  ```
- `profile_app_stack::db_host`: `localhost` (type: string)
- `profile_app_stack::db_port`: `5432` (type: integer)
- `profile_app_stack::db_name`: `myapp_db` (type: string)
- `profile_app_stack::db_user`: `myapp_app` (type: string)
- `profile_app_stack::db_password`: `ENC[PKCS7,MIIBygYJKoZIhvcNAQcDoIIBuzCCAbcCAQAxggEhMIIBHQIBADAFMAACAQEwDQYJKoZIhvcNAQEBBQAEggEAdbPassword]` (type: string, encrypted)
- `profile_app_stack::worker_count`: `2` (type: integer)
- `profile_app_stack::worker_class`: `uvicorn.workers.UvicornWorker` (type: string)
- `profile_app_stack::max_requests`: `1000` (type: integer)
- `profile_app_stack::graceful_timeout`: `30` (type: integer)
- `profile_app_stack::log_dir`: `/var/log/myapp-api` (type: string)
- `profile_app_stack::log_level`: `info` (type: string)
- `profile_app_stack::log_max_size`: `100M` (type: string)
- `profile_app_stack::log_rotate_count`: `7` (type: integer)

**environment/production.yaml (environment overrides)** → Migration note: Production-specific variables
- `profile_app_stack::app_revision`: `v2.4.1` (type: string)
- `profile_app_stack::worker_count`: `8` (type: integer)
- `profile_app_stack::max_requests`: `5000` (type: integer)
- `profile_app_stack::log_level`: `warning` (type: string)
- `profile_app_stack::db_host`: `db-primary.prod.internal` (type: string)
- `profile_app_stack::db_port`: `5432` (type: integer)
- `profile_app_stack::secret_key`: `ENC[PKCS7,MIIBygYJKoZIhvcNAQcDoIIBuzCCAbcCAQAxggEhMIIBHQIBADAFMAACAQEwDQYJKoZIhvcNAQEBBQAEggEAProdSecret]` (type: string, encrypted)

**environment/staging.yaml (environment overrides)** → Migration note: Staging-specific variables
- `profile_app_stack::app_revision`: `main` (type: string)
- `profile_app_stack::worker_count`: `1` (type: integer)
- `profile_app_stack::max_requests`: `100` (type: integer)
- `profile_app_stack::log_level`: `debug` (type: string)
- `profile_app_stack::db_host`: `localhost` (type: string)
- `profile_app_stack::secret_key`: `staging-not-secret-at-all` (type: string, plaintext)

### Variable Migration Summary

- **Common defaults**: 22 variables from common.yaml (base configuration for all nodes)
- **Environment-specific variables**: 6 variables that vary by deployment environment (production, staging)
- **Encrypted variables**: 2 variables that are encrypted (eyaml) and need secure storage (db_password, secret_key in production)

### Cross-Level Overrides

Variables defined at multiple Hiera levels:
- **profile_app_stack::app_revision**: defined at common, production, staging levels, merge strategy: first
- **profile_app_stack::worker_count**: defined at common, production, staging levels, merge strategy: first
- **profile_app_stack::max_requests**: defined at common, production, staging levels, merge strategy: first
- **profile_app_stack::log_level**: defined at common, production, staging levels, merge strategy: first
- **profile_app_stack::db_host**: defined at common, production, staging levels, merge strategy: first
- **profile_app_stack::secret_key**: defined at production, staging levels, default value in init.pp: 'changeme'

### Merge Strategy Notes

- All variables use `first` merge strategy - first value found wins, no merging

## Dependencies

**External module dependencies**:
- puppetlabs-stdlib (forge, version: 9.7.0)
- puppetlabs-concat (forge, version: 9.0.2)
- puppetlabs-firewall (forge, version: 8.1.3)
- puppetlabs-vcsrepo (forge, version: 6.1.0)
- puppet-redis (forge, version: 11.0.0)
- puppetlabs-apt (forge, version: 9.4.0)

**System package dependencies**:
- python3, python3-pip, python3-venv, python3-dev
- git, build-essential
- postgresql, postgresql-contrib, libpq-dev (when db_host is localhost)
- cron
- prometheus-node-exporter, prometheus-pushgateway (in production)

**Service dependencies**:
- postgresql (when db_host is localhost)
- myapp-api (application service)
- prometheus-node-exporter (in production)

## Puppet Facts Used

- `$facts['environment']` - Current Puppet environment (production, staging)
- `$facts['kernel']` - Operating system kernel (Linux, Windows, etc.)

## Template Conversion Notes

### app.env.erb
- **Variables used**: db_url, app_name, app_port, secret_key, log_level, log_dir, worker_count
- **Ruby logic blocks**: Conditional block checking if environment is production
- **Conditional rendering**: If environment is production, sets DEBUG=false and specific CORS_ORIGINS; otherwise sets DEBUG=true and CORS_ORIGINS=*

### app.service.epp
- **Variables used**: app_name, app_dir, app_user, app_group, app_port, worker_count, worker_class, max_requests, graceful_timeout, log_dir, log_level
- **Complex expressions**: Calculates TimeoutStopSec as graceful_timeout + 5

### logrotate.conf.erb
- **Variables used**: log_dir, log_rotate_count, log_max_size, app_name
- **Ruby logic blocks**: None, simple variable substitution

## Checks for the Migration

**Files to verify**:
- /opt/myapp-api/.env
- /etc/systemd/system/myapp-api.service
- /etc/logrotate.d/myapp-api
- /usr/local/bin/app-healthcheck.sh
- /usr/local/bin/db-backup.sh

**Service endpoints to check**:
- http://localhost:8000/health

**Templates rendered**:
- app.env.erb → /opt/myapp-api/.env (1 instance)
- app.service.epp → /etc/systemd/system/myapp-api.service (1 instance)
- logrotate.conf.erb → /etc/logrotate.d/myapp-api (1 instance)

## Pre-flight checks:
```bash
# Service status commands
systemctl status myapp-api
# Instance-specific checks
curl -f http://localhost:8000/health
# Configuration validation commands
sudo -u postgres psql -c "\l" | grep myapp_db  # when db_host is localhost
```