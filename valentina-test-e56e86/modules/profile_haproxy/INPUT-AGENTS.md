## Team-Based Code Organization

When analyzing Puppet code, identify components that align with team divisions: linux, windows, db, automation. This categorization will inform the structure of the migrated Ansible codebase.

---

## Credential Management

During analysis of Puppet modules, identify all credentials used for target systems. Note that in the target Ansible environment, all credentials for targets to be automated are stored in cyberark.

---

## Patching Use Case Analysis

When analyzing Puppet patching code, identify components that can be developed as an overarching use case in Ansible. Look for code that could leverage other modules for OS, application, DB or other depending on the target being patched.