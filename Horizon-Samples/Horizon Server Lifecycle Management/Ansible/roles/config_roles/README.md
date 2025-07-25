Config Roles
============

This Ansible role manages Horizon Server Role configuration API. It supports listing existing roles and creating new roles via REST API calls.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)

Role Variables
--------------

Variables are typically provided via `vars_files` in your playbook. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (see `vars/api_vars.yml`).
- `token`: Bearer token for API authentication.
- `create_role`: Dictionary describing the role to create (name, description, privileges).

Example
=======
create_role:
  description: "Horizon Server Lifecycle Management Administrators"
  name: "LCM Admin"
  privileges: ["LCM_MANAGEMENT"]

Dependencies
============
horizon_server_api_auth: For API authentication and token retrieval.

Example Playbook
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: Authenticate and get token
      include_role:
        name: horizon_server_api_auth

    - name: List roles
      include_role:
        name: config_roles
        tasks_from: list
      vars:
        token: "{{ api_auth_token }}"

    - name: Create role if not exists
      include_role:
        name: config_roles
        tasks_from: create
      vars:
        token: "{{ api_auth_token }}"

License
=======
BSD

Author Information
==================
bsg@omnissa.com