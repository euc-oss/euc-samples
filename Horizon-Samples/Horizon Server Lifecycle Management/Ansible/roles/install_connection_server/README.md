install_connection_server
========================

This Ansible role automates the installation of Omnissa Horizon Connection Server components (Standard, Replica, and Enrollment servers) via REST API calls.

Role Structure
--------------

- `tasks/cs.yml`: Installs Standard Connection Servers.
- `tasks/rs.yml`: Installs Replica Servers.
- `tasks/es.yml`: Installs Enrollment Servers.

Requirements
------------

- Ansible 2.9 or higher
- Horizon Server REST API endpoint accessible
- API authentication token (see `horizon_server_api_auth` role)
- Server installer package uploaded and available

Role Variables
--------------

Variables should be defined in your playbook or a `vars` file. Key variables include:

- `api_base_url`: Base URL for the Horizon Server REST API.
- `api_endpoints`: Dictionary of API endpoint paths (must include `install_connection_server`).
- `token`: Bearer token for API authentication.
- `package_id`: ID of the uploaded server installer package.
- `install_parameters`: Dictionary containing installation parameters (see below).
- `connection_server`: List of FQDNs for Standard Connection Servers.
- `replica_servers`: List of FQDNs for Replica Servers.
- `enrollment_servers`: List of FQDNs for Enrollment Servers.

- `install_parameters`:
install_parameters:
  domain: "yourdomain.local"
  password: "yourpassword"
  user_name: "administrator"
  server_msi_install_spec:
    admin_sid: "S-1-5-21-..."
    deployment_type: "CONNECTION_SERVER"
    fips_enabled: false
    fw_choice: "enable"
    html_access: true
    install_directory: "C:\\Program Files\\VMware\\..."
    server_recovery_pwd: "recoverypassword"
    server_recovery_pwd_reminder: "reminder"
    vdm_ipprotocol_usage: "IPv4"

Usage
=====
Include the role and specify which server type to install by using the appropriate task file:

- hosts: localhost
  gather_facts: no
  vars_files:
    - [secure_vars.yml](http://_vscodecontentref_/0)
    - [api_vars.yml](http://_vscodecontentref_/1)
  tasks:
    - name: Install Standard Connection Servers
      include_role:
        name: install_connection_server
        tasks_from: cs

    - name: Install Replica Servers
      include_role:
        name: install_connection_server
        tasks_from: rs

    - name: Install Enrollment Servers
      include_role:
        name: install_connection_server
        tasks_from: es


License
=======
BSD

Author Information
==================
bsg@omnissa.com
