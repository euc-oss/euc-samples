# Workspace ONE Sensors

## Overview
- **Authors**:Bhavya Bandi, Varun Murthy, Josue Negron, Brooks Peppin, Aaron Black, Mike Nelson, Chris Halstead, Justin Sheets, Andreano Lanusse, Adarsh Kesari, Saurabh Jhunjhunwala, Robert Terakedis, Phil Helmling
- **Email**: bbandi@vmware.com, vmurthy@vmware.com, jnegron@vmware.com, bpeppin@vmware.com, aaronb@vmware.com, miken@vmware.com, chalstead@vmware.com, jsheets@vmware.com, aguedesrocha@vmware.com, kesaria@vmware.com, sjhunjhunwal@vmware.com, rterakedis@vmware.com, helmlingp@vmware.com
- **Date Created**: 11/14/2018
- **Updated**: 05/14/2024
- **Supported Platforms**: Workspace ONE 1811+
- **Tested on**: Windows 10 Pro/Enterprise 1803+

## DISCLAIMER
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
   VMWARE,INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
   IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Purpose
These Workspace ONE Sensor samples contain PowerShell, BASH and Shell scripts that can be used in a **Resources > Sensors** payload to report back information about the Windows, macOS or Linux device back to Workspace ONE.

## Description 
There are Sensor samples, templates, and a script `import_sensor_samples.ps1` to populate your environment with all of the samples.
Many of these sensors are also available for deployment directly to your Workspace ONE UEM environment from within the Workspace ONE Marketplace. Workspace ONE Marketplace is available within the ![Workspace ONE Cloud Service](https://connect.omnissa.com).

## Required Changes/Updates
None. Simply copy the desired sensors to a directory that includes the `import_sensor_samples.ps1` script or use the `-SensorsDirectory` parameter to specify a directory. Then run the `import_sensor_samples.ps1` script specifying your environment details. Alternatively, copy the contents of each sensor and create a new Sensor manually within your Workspace ONE UEM Console.

You can use the sample sensors or the Templates as a basis for the specific sensors you need.
Remember to ensure your Return Value matches the actual value type specified in the Sensor.

For Windows Samples be sure to use the following format when creating new samples so that they are imported correctly:

   ```
   # Description: Description
   # Execution Context: SYSTEM | USER
   # Execution Architecture: EITHER64OR32BIT | ONLY_32BIT | ONLY_64BIT | LEGACY
   # Return Type: INTEGER | BOOLEAN | STRING | DATETIME
   <YOUR POWERSHELL COMMANDS>
   ```
   
   For macOS Samples be sure to use the following format when creating new samples so that they are imported correctly:
   ```
   <YOUR SENSOR COMMANDS>
   # Description: Description
   # Execution Context: SYSTEM | USER
   # Return Type: INTEGER | BOOLEAN | STRING | DATETIME
   # Variables: KEY,VALUE; KEY,VALUE
   ```

For Linux Samples be sure to use the following format when creating new samples so that they are imported correctly:
   ```
   <YOUR SCRIPT COMMANDS>
   # Description: Description
   # Execution Context: SYSTEM | USER
   # Return Type: INTEGER | BOOLEAN | STRING | DATETIME
   # Variables: KEY,VALUE; KEY,VALUE
   # Platform: LINUX
   ```

## Workspace ONE Sensors Importer


### Synopsis 
This Powershell script allows you to automatically import PowerShell/Shell (.sh & .zsh)/Python scripts (Sensor Samples) as Workspace ONE Sensors into your Workspace ONE UEM Console.

### Description 
Place this PowerShell script in the same directory as all of your samples (.ps1, .sh, .zsh, .py files, note file extension is not required, sha-bang will be used to determine scripting language), or use the `-SensorsDirectory` parameter to specify your directory. This script when run, will parse the sensor sample scripts, check if they already exist, then upload to Workspace ONE UEM via the REST API. 

If the `-UpdateSensors` parameter is provided, existing sensors with the same name will have all metadata and Sensor Code updated in the console.

If the `-SmartGroupName` or `-SmartGroupID` parameters are provided, Sensors uploaded will also be assigned to the specified Smart Group. If the Sensor already exists, the script will only add the Smart Group assignment if it doesn't exist already.

***The OrganizationGroupName and SmartGroupName parameters use a search function. If multiple Organization Group or Smart Groups are returned, a choice prompt will allow selection of the correct Group.***

If the `-Platform` parameter is provided, only sensors matching the specified platform will be imported or updated.

The `import_sensor_samples.ps1` script must be run as an Administrator user on a Windows device. The script can also be run on a macOS device as long as Powershell is installed.

### Examples 

- **Basic**: this command shows all required fields and will scan the current directory and upload the samples to Workspace ONE UEM Console via the REST API using the credentials provided. ***The OrganizationGroupName parameter uses a search function. If multiple Organization Groups are returned, a choice prompt will allow selection of the correct Origanization Group.***

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
   ```

- **Custom Directory**: using the `-SensorsDirectory` parameter tells the script where your samples exist. The directory provided must have script files which you want uploaded as Sensors. 

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
      -SensorsDirectory 'C:\Users\G.P.Burdell\Downloads\Sensors'
   ```

- **Assign to Smart Group**: using the `-SmartGroupID` OR `-SmartGroupName` parameter will assign all Sensors imported or updated to that chosen Smart Group. This command is used best in a test environment to quickly test Sensors before moving Sensors to production, however it is also a great way to add assignments to many sensors. Obtain the Smart Group ID via API or by hovering over the Smart Group name in the console and looking at the ID at the end of the URL to use `-SmartGroupID`. ***The SmartGroupName parameter uses a search function. If multiple Smart Groups are returned, a choice prompt will allow selection of the correct Smart Group.***

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
      -SmartGroupName 'All Devices'
   ```

- **Assign to Smart Group and Set EVENT Triggers**: using the `-TriggerType` you can choose to trigger on `EVENT` or `SCHEDULE`. When using **EVENT** as a TriggerType provide the trigger(s): **LOGIN**, **LOGOUT**, **STARTUP**, **USER_SWITCH**. When using **SCHEDULE** or if not specifying a TriggerType, then the default Sensor interval of 6 hours will be used, and the Event triggers will be ignored.

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'  
      -SmartGroupName 'All Devices'
      -TriggerType 'EVENT'
      -LOGIN -LOGOUT -STARTUP -USER_SWITCH
   ```

- **Delete All Sensors**: using the `-DeleteSensors` switch parameter will delete ALL Sensors in the target Organization Group, including Sensors manually added! This is destructive and not reversible.

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
      -DeleteSensors
   ```

- **Update Sensors or Overwrite Existing Sensors**: using the `-UpdateSensors` switch parameter will update the Sensors that already exist with the version being uploaded. This is best used when updates and fixes are published to the source Sensor samples.

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
      -UpdateSensors
   ```

- **Export All Sensors**: using the `-ExportSensors` switch parameter will export ALL Sensors that exist in the target Organization Group, including Sensors manually added! This is a good option for backing up sensors before making updates, or copying from UAT to PROD for example.

   ```
   .\import_sensor_samples.ps1
      -WorkspaceONEServer 'https://as###.awmdm.com'
      -WorkspaceONEAdmin 'administrator'
      -WorkspaceONEAdminPW 'P@ssw0rd'
      -WorkspaceONEAPIKey 'YeJtOTx/v2EpXPIEEhFo1GfAWVCfiF6TzTMKAqhTWHc='
      -OrganizationGroupName 'Digital Workspace Tech Zone'
      -ExportSensors
   ```

### Parameters 
**-WorkspaceONEServer**: REST API URL for the Workspace ONE UEM API Server e.g. https://as###.awmdm.com without the ending /API. Navigate to **All Settings -> System -> Advanced -> API -> REST API**.

**-WorkspaceONEAdmin**: An Workspace ONE UEM admin account in the tenant that is being queried.  This admin must have the API role at a minimum.

**-WorkspaceONEAdminPW**: The password that is used by the admin specified in the admin parameter

**-WorkspaceONEAPIKey**: This is the REST API key that is generated in the Workspace ONE UEM Console.  You locate this key at **All Settings -> System -> Advanced -> API -> REST API**,
and you will find the key in the **API Key** field.  If it is not there you may need override the settings and Enable API Access. 
![](https://i.imgur.com/CjiC2Qt.png)

**-OrganizationGroupName**: (OPTIONAL) The display name of the Organization Group. You can find this at the top of the console, normally your company's name. This parameter uses a function to search the tenant for the OrganizationGroupName. If multiple Organization Groups are returned, a choice prompt will allow selection of the correct Organization Group. **Required to provide OrganizationGroupName or OrganizationGroupID.** 

**-OrganizationGroupID**: (OPTIONAL) The Group ID of the Organization Group. You can find this by hovering over your Organization's Name in the console. **Required to provide OrganizationGroupName or OrganizationGroupID.**
![](https://i.imgur.com/lWjWBsF.png)

**-SensorsDirectory**: (OPTIONAL) The directory your sensors samples are located, default location is the current directory this PowerShell script is running from. 

**-SmartGroupName**: (OPTIONAL) If provided, sensors imported will be assigned to this Smart Group. Existing assignments will NOT be overwritten, only added to. Navigate to **Groups & Settings > Groups > Assignment Groups**. The Smart Group Name is the friendly name displayed in the Groups column. The script will default to using Managed By = Organization Group used above. This option can also be used to assign many sensors quickly. **If wanting to assign, you are required to provide SmartGroupID or SmartGroupName.**

**-SmartGroupID**: (OPTIONAL) If provided, sensors imported will be assigned to this Smart Group. Existing assignments will NOT be overwritten, only added to. Navigate to **Groups & Settings > Groups > Assignment Groups**. Hover over the Smart Group, then look for the number at the end of the URL, this is your Smart Group ID. This option can also be used to assign many sensors quickly. **If wanting to assign, you are required to provide SmartGroupID or SmartGroupName.**
![](https://i.imgur.com/IjvkoGC.png)

**-DeleteSensors**: (OPTIONAL) If enabled, all sensors in your environment will be deleted. This action is destructive and cannot be undone. Ensure you are targeting the correct Organization Group. 

**-UpdateSensors** (OPTIONAL) If enabled, sensors imported that match an existing sensor by name in the specified Organization Group Name, will have the Description, Platform Architecture, Return Type and Sensor Code updated in the console. When combined with `-SmartGroupName` or `-SmartGroupID`, these Sensors will also be assigned to the specified Smart Group if not already assigned.

**-Platform** (OPTIONAL) If enabled, determines what platform's sensors to import. Supported values are **Windows**, **macOS** or **Linux**. Only a single value is supported for this option, so keep disabled to import all platforms or run once for each platform. 

**-ExportSensors** (OPTIONAL) If enabled, all sensors will be downloaded locally, this is a good option for backing up sensors before making updates. 

**-TriggerType** (OPTIONAL) When bulk assigning, provide the Trigger Type: **SCHEDULE**, **EVENT**, or **SCHEDULEANDEVENT**. If omitted, all sensors assigned to a Smart Group will have a Trigger Type of Schedule, which is a default of running every 6 hours.

**-LOGIN** (OPTIONAL) When using **Event** as **TriggerType**

**-LOGOUT** (OPTIONAL) When using **Event** as **TriggerType**

**-STARTUP** (OPTIONAL) When using **Event** as **TriggerType**

**-USER_SWITCH** (OPTIONAL) When using **Event** as **TriggerType**

## Resources 
- [macOS Custom Attributes to Sensors Migration Script](https://github.com/vmware-samples/euc-samples/tree/master/macOS-Samples/Tools/CustomAttributesToSensorsMigration)
- [macOS Custom Attributes Repo](https://github.com/vmware-samples/euc-samples/tree/master/macOS-Samples/CustomAttributes)

## Change Log
- 05/14/2024 - Update import_sensor_samples.ps1 with logic changes to Update and Assign Sensors as well as clearer status messages. Updated README.md to reflect changes.
- 05/17/2023 - Updated README.md and cleaned up import_sensor_samples.ps1
- 01/04/2023 - Update import_sensor_samples.ps1 to only assign uploaded Sensors to specified SGs rather than all Sensors within the Console
- 2/17/2023 - added new sensors, update import_sensor_samples.ps1 script, add standardized header format to enable more reliable import.
- 9/24/2021 - Added sensors to assist with Windows 11 Readiness dashboards and reports.
- 2/1/2021 - Updated README.md. Added ability to use Organization Group ID or Name and Smart Group ID or Name. 
- 1/15/2021 - Added support for macOS. The script will now import macOS sensors automatically. Support downloading macOS sensors. Added new platform parameter to force only "Windows" or "macOS" sensors to be imported. Updated OrganizationGroupID back to OrganizationGroupName and takes in the friendly name or customer name value and NOT group ID. e.g. ACME Corp, Inc. and not acme1234. 
- 1/6/2021 - fixed issue with OrganizationGroupName; renamed to OrganizationGroupID
- 12/24/2020 - Updated import_sensor_samples.ps1 (version 3.0) file. Updated Bulk Assign to leverage new Assignment APIs. Added ability to set trigger type and event triggers. Updated "OrganizationGroupName" to "OrganizationGroupID" to reduce confusion. 
- 9/14/2020 - Removed pre-check for console version and if sensors are enabled.
- 8/10/2020 - Added samples for oma-dm sync troubleshooting
- 8/3/2020 - Fix issue with bitlocker_encryption_method.ps1 sample
- 7/24/2020 - Added os_disk_free_space sensor sample. 
- 5/28/2020 - Added ability to download/export all Sensors from console to import_sensor_samples.ps1 file (version 1.3). Added various branchcache samples.
- 5/28/2020 - updated import_sensor_samples.ps1 (version 1.2) file. Fixed bug with -DeleteSensors parameter. Added additional logging. 
- 3/26/2020 - os_product_key added
- 3/13/2020 - dcu_version and dcu_lock added
- March 2020 - many BranchCache samples bc_*
- 1/2/2020 - Fixed example, missing ` which produced an error when running the example provided in import_sensor_samples.ps1 file. 
- 8/5/2019 - Added os_browser_default which returns the default web browser set on the device. Thank you for the contribution Roar Myklebust. 
- 8/2/2019 - Updated samples, updated README.md, moved template_ samples into a folder named Templates.
- 5/9/2019 - Added branch cache samples and fixed java version sample
- 5/6/2019 - Added battery health percentage
- 5/6/2019 - Added switch parameters for overwriting/updating and deleting Sensors. 
- 5/2/2019 - Added Hash, Folder Size samples and templates
- 4/26/2019 - Force use of TLS 1.2 for REST API Calls; fixed minor issues
- 12/6/2018 - Added more details on how to use import_sensor_samples.ps1
- 12/5/2018 - Added import_sensor_samples.ps1 and updated system_type, system_status, system_date, templates, system_family
- 12/3/2018 - added system_pc_type, system_status, system_family, system_type, system_thermal_state, system_wakeup_type, system_model, system_manufacturer, system_hypervisor_present, system_dns_hostname, system_username, system_name, system_domain_role, system_domain_membership, system_domain_name
- 11/30/2018 - added os_verison, os_build_version, os_build_number, os_architecture, os_edition, system_timezone, bitlocker_encryption_method, horizon_broker_url, horizon_protocol, template_get_wmi_object, template_get_registry_value
- 11/21/2018 - updated bios_secure_boot and bios_serial_number
- 11/15/2018 - changed echo to write-output in all samples
- 11/14/2018 - Uploaded README file
