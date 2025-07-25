horizon_server_api_auth
=======================

This Ansible role authenticates with the Horizon Server REST API and retrieves a bearer token for use in subsequent API calls.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible

Role Variables
--------------

The following variables must be defined (typically in your playbook or a `vars` file):

- `api_base_url`: Base URL for the Horizon Server REST API (e.g., `https://your-horizon-server/api`).
- `api_endpoints`: Dictionary containing endpoint paths, must include a `login` key (e.g., `/v1/login`).
- `api_username`: Username for API authentication.
- `api_password`: Password for API authentication.
- `api_domain`: Domain for API authentication (if required).

Outputs
=======
api_auth_token: The bearer token to use in subsequent API requests.

Example
=======
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: Authenticate and get token
      include_role:
        name: horizon_server_api_auth

    - name: Use token in another role
      include_role:
        name: config_roles
        tasks_from: list
      vars:
        token: "{{ api_auth_token }}"

License
=======
BSD

Author Information
==================
bsg@omnissa.com
