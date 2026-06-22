## Code Repository Structure

Each team's code should be divided in ansible code (as playbooks, roles, collections, configuration templates) and configuration as code (as job templates, credentials, inventories, schedules, workflows)

---

## Team-Based Organization

Divide codebase based on teams, linux, windows, db, automation

---

## Credential Management

All credentials for targets to be automated are stored in cyberark

---

## GitHub Actions Integration

All migrated Ansible projects must include a GitHub Actions workflow that runs `ansible-lint` on every pull request. No code reaches `main` without passing lint.

Include this workflow in `.github/workflows/ansible-ci.yml`:

```yaml
name: Ansible CI
on:
  pull_request:
    branches: [main]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ansible-lint
      - run: ansible-lint roles/ --strict
```

---

## Patching Implementation

Patching use case code, should be developed as overarching use case and should leverage other modules for os, application, db or other depending on the target being patched. patching process in ansible should rely on fetching patching schedules from service now and execute patching and verification in lower environment, then with the ability to apply it after manual confirmation to production environment