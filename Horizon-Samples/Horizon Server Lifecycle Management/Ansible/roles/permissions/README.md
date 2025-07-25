permissions
===========

This Ansible role manages Horizon Server permissions via REST API calls. It supports listing current permissions and assigning new permissions to roles and users/groups.

Role Structure
--------------

- `tasks/list.yml`: Lists all current permissions.
- `tasks/assign.yml`: Assigns a permission to a user/group for a specific role, if not already assigned.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)

Role Variables
--------------

Variables should be defined in your playbook or a `vars` file. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (must include `list_permissions` and `assign_permissions`).
- `token`: Bearer token for API authentication.
- `role_id`: The ID of the role to assign permissions to.
- `assign_permissons`: Dictionary describing the permission assignment.

Example 
`assign_permissons`:
assign_permissons:
  ad_user_or_group_id: "S-1-5-21-..."
  local_access_group_id: "local-group-id"
  federation_access_group_id: "federation-group-id"  # If CPA enabled


Usage
======
Include the role and specify which task to run:
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: List permissions
      include_role:
        name: permissions
        tasks_from: list
      vars:
        token: "{{ api_auth_token }}"

    - name: Assign permission to role
      include_role:
        name: permissions
        tasks_from: assign
      vars:
        token: "{{ api_auth_token }}"
        role_id: "your-role-id"
        assign_permissons:
          ad_user_or_group_id: "S-1-5-21-..."
          local_access_group_id: "local-group-id"

Outputs
=======
Shows the current permissions and assignment results.
Asserts successful assignment and displays errors if any.

License
=======
BSD

Author Information
==================
bsg@omnissa.com
