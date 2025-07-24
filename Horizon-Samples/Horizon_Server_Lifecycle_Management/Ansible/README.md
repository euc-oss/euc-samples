# Horizon Server Lifecycle Management

Author: Guruprasad B S, Omnissa
Last Edit: July 24,2025
Version 1.0 

<!-- Summary Start -->

Horizon server lifecycle management refers to the automation and simplification of installing and upgrading Omnissa Horizon Connection Server and Enrollment Server instances using Lifecycle Management (LCM) APIs. 
These APIs, introduced in Horizon 8 version 2406, allow administrators to automate these processes and manage the server's lifecycle more efficiently. 

Documentation : https://docs.omnissa.com/bundle/Horizon8InstallUpgrade/page/AutomatingUpgradesofConnectionServerWithLCMAPIs.html

<!-- Summary End -->

Key aspects of Horizon server lifecycle management include:
----------------------------------------------------------
Automation of Installations and Upgrades:
      The LCM APIs enable automated installations and upgrades of Connection Servers and Enrollment Servers,
      reducing  manual effort and potential errors. 

REST API Endpoints:
     The API utilizes RESTful endpoints for managing installations and upgrades, allowing for programmatic control and
     integration with other systems. 

Installer Status Monitoring:
     An installer status API endpoint is available to monitor the progress of automated upgrades, providing visibility into
     the process. 

Prerequisites Validation:
      APIs allow you to validate that the target machines meets the appropriate requirements. Which includes – System ,
      Active Directory and vCenter prerequisite.


We can use Ansible to automate the lifecycle management of  Horizon 8 deployments using LCM API’s.
The standard prerequisites apply when using LCM APIs with the Ansible.

Folder Structure:
----------------
Horizon_Server_Lifecycle_Managemnt --|
                                     |--- inventory 			
					                           |--- playbooks (Install and Upgrade playbooks)
                                     |--- vars  (Parameters required for playbook execution)
                                     |--- roles (role to invoke LCM API endpoints.)
                                     |--- ansible.cfg (config file)                                                                

Note: You can define the necessary parameters for each role in the corresponding "roles/<role name>/defaults/main.yml" file. Alternatively, you have the option to override these parameters at the playbook level by including them in the vars/api_vars.yml file.

Command to execute upgrade flow:
-------------------------------
Change directory to playbooks and execute - ansible-playbook Horizon_Server_Upgrade.yml

Command to execute Install flow:
-------------------------------
Change directory to playbooks and execute - ansible-playbook Horizon_Server_Install.yml
                                                                   
