server_installer_packages
========================

This Ansible role manages Horizon Server installer packages via REST API calls. It supports listing available packages and registering new server installer packages if not already present.

Role Structure
--------------

- `tasks/list.yml`: Lists all registered server installer packages.
- `tasks/register.yml`: Registers a new server installer package if not already registered.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)

Role Variables
--------------

Variables should be defined in your playbook or a `vars` file. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (must include `list_packages` and `register`).
- `token`: Bearer token for API authentication.
- `server_installer`: Dictionary describing the installer package to register.

Example :
server_installer:
  build_number: "12345"
  checksum: "abcdef1234567890"
  display_name: "Horizon Connection Server 8.10"
  file_size_in_bytes: 123456789
  filename: "VMware-Horizon-Connection-Server-8.10.exe"
  version: "8.10"
  file_url: "https://your-storage/path/VMware-Horizon-Connection-Server-8.10.exe"


Usage
=====
Include the role and specify which task to run:
- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml]
    - [api_vars.yml]
  tasks:
    - name: List server installer packages
      include_role:
        name: server_installer_packages
        tasks_from: list
      vars:
        token: "{{ api_auth_token }}"

    - name: Register server installer package if not present
      include_role:
        name: server_installer_packages
        tasks_from: register
      vars:
        token: "{{ api_auth_token }}"
        server_installer:
          build_number: "12345"
          checksum: "abcdef1234567890"
          display_name: "Horizon Connection Server 8.10"
          file_size_in_bytes: 123456789
          filename: "VMware-Horizon-Connection-Server-8.10.exe"
          version: "8.10"
          file_url: "https://your-storage/path/VMware-Horizon-Connection-Server-8.10.exe"

Outputs
=======
package_id: The ID of the registered or matched server installer package.
Debug output for package registration and listing.

License
=======
BSD

Author Information
==================
bsg@omnissa.com