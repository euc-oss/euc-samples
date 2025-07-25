precheck
========

This Ansible role performs pre-installation validation checks for Omnissa Horizon Connection Server deployments. It calls Horizon Server REST API endpoints to verify system, Active Directory, vCenter, and LDAP requirements for all target servers.

Role Structure
--------------

- `tasks/system.yml`: Validates system requirements on target servers.
- `tasks/ad.yml`: Validates Active Directory requirements.
- `tasks/vcenter.yml`: Validates vCenter requirements.
- `tasks/ldap.yml`: Validates LDAP requirements.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)
- List of target server FQDNs to check

Role Variables
--------------

Variables should be defined in your playbook or a `vars` file. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (must include `validate_system_requirements`, `validate_ad_requirements`, `validate_vCenter_requirements`, `validate_ldap_requirements`).
- `token`: Bearer token for API authentication.
- `target_servers`: List of FQDNs for servers to check.
- `precheck`: Dictionary containing required versions and connection details for AD, vCenter, etc.

Example:
precheck:
  cs_version: "8.10"
  ad:
    fqdn: "ad.domain.local"
  vc:
    fqdn: "vcenter.domain.local"
    version: "7.0"

Usage
=====
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml](http://_vscodecontentref_/0)
    - [api_vars.yml](http://_vscodecontentref_/1)
  tasks:
    - name: Run system precheck
      include_role:
        name: precheck
        tasks_from: system

    - name: Run Active Directory precheck
      include_role:
        name: precheck
        tasks_from: ad

    - name: Run vCenter precheck
      include_role:
        name: precheck
        tasks_from: vcenter

    - name: Run LDAP precheck
      include_role:
        name: precheck
        tasks_from: ldap

Outputs
=======
Fails the play if any server does not pass the required checks.
Displays a message if all servers pass the checks.

License
=======
BSD

Author Information
==================
bsg@omnissa.com