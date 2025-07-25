install_status_check
===================

This Ansible role polls the Horizon Server REST API to check the installation status of one or more servers (Connection, Replica, or Enrollment servers). It supports automatic re-authentication if the API token expires and collects status results for all target servers.

Role Structure
--------------

- `tasks/poll_status.yml`: Entry point. Initializes polling for all target servers.
- `tasks/poll_iteration.yml`: Handles polling in iterations, removing completed servers from the pending list.
- `tasks/poll_single_server.yml`: Polls the API for a single server's status, handles re-authentication, and updates results.

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
- `api_endpoints`: Dictionary of API endpoint paths (must include `install_status`).
- `token`: Bearer token for API authentication.
- `target_servers`: List of FQDNs for servers whose install status should be checked.
- `expected_status`: The status string that indicates installation is complete (e.g., `"INSTALLED"`).

Example:
api_base_url: "https://your-horizon-server/api"
api_endpoints:
  install_status: "/v1/servers/install-status"
token: "{{ api_auth_token }}"
target_servers:
  - "server1.domain.local"
  - "server2.domain.local"
expected_status: "INSTALLED"

Usage
======
Include the role in your playbook and invoke the polling process:
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: Check install status for servers
      include_role:
        name: install_status_check
        tasks_from: poll_status

Outputs
=======
install_status_results: Dictionary mapping each server FQDN to its final status (e.g., { "server1.domain.local": "POST_INSTALLATION_CHECK_SUCCESS" }).

Features
========
Polls all target servers in parallel, removing completed ones each iteration.
Handles API token expiration by re-authenticating as needed.
Waits 60 seconds between polling attempts for each server.
Collects and displays error messages if present.

License
=======
BSD

Author Information
==================
bsg@omnissa.com