upgrade_connection_server
========================

This Ansible role automates the upgrade of Omnissa Horizon Connection Servers via REST API calls. It triggers the upgrade process for one or more target servers using a specified installer package.

Role Structure
--------------

- `tasks/main.yml`: Main task file that performs the upgrade for all specified target servers.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)
- Server installer package already registered and available

Role Variables
--------------

Variables should be defined in your playbook or a `vars` file. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (must include `upgrade_connection_server`).
- `token`: Bearer token for API authentication.
- `package_id`: ID of the uploaded server installer package to use for the upgrade.
- `install_parameters`: Dictionary containing upgrade parameters (see below).
- `target_servers`: List of FQDNs for servers to upgrade.

- `install_parameters`:
    domain: "yourdomain.local"
    password: "yourpassword"
    user_name: "administrator"

Usage
=====
Include the role in your playbook and provide the required variables:
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: Upgrade Connection Servers
      include_role:
        name: upgrade_connection_server
      vars:
        token: "{{ api_auth_token }}"
        package_id: "your-package-id"
        install_parameters:
          domain: "yourdomain.local"
          password: "yourpassword"
          user_name: "administrator"
        target_servers:
          - "server1.domain.local"
          - "server2.domain.local"

Outputs
=======
Fails the play if any server upgrade does not return status 204.
failed_server: List of servers that failed to upgrade.

License
=======
BSD

Author Information
==================
bsg@omnissa.com