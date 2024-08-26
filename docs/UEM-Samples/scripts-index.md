---
layout: default
title: Workspace ONE Scripts Samples
hide:
  #- navigation
  - toc
---

## Code Samples

This is an index of Code Samples within the UEM-Samples/Scripts area.

## Workspace ONE Scripts Samples

| Platform | Sample Name | Summary | Link |
| --- | --- | --- | ---:|
| macOS | Check macOS Device Checkin in Carbon Black Cloud.sh | Check macOS Device Registered in Carbon Black Cloud as per https://community.carbonblack.com/t5/Knowledge-Base/Carbon-Black-Cloud-How-To-Check-DeviceID-On-Endpoint-macOS-3-5-x/ta-p/111757 | [Check macOS Device Checkin in Carbon Black Cloud.sh](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/macOS/Check%20macOS%20Device%20Checkin%20in%20Carbon%20Black%20Cloud.sh) |
| macOS | DockUtil Post-Install.sh | There are times where it would be useful to add icons to the users dock after installing a new application.   The following script can be added as a post-install script in order to call an open source utility script (dockutil) to add the item as desired. | [DockUtil Post-Install.sh](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/macOS/DockUtil%20Post-Install.sh) |
| Windows | check_windows_device_checkin_in_carbon_black_cloud.ps1 | Check Windows Device Checkin in Carbon Black Cloud | [check_windows_device_checkin_in_carbon_black_cloud.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/check_windows_device_checkin_in_carbon_black_cloud.ps1) |
| Windows | delete_nonenrolled_userprofilefolders.ps1 | Script to delete user profile folders not accessed for more than x month(s). Does NOT delete user profile folder of enrolled user as this breaks enrollment. | [delete_nonenrolled_userprofilefolders.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/delete_nonenrolled_userprofilefolders.ps1) |
| Windows | Delete_WSUS_Reg_Keys.ps1 | Deletes the SCCM WSUS registry keys that prevent a Windows 10 machine from using a modern managed Windows Update Profile. | [Delete_WSUS_Reg_Keys.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/Delete_WSUS_Reg_Keys.ps1) |
| Windows | GenerateLocalAdministratorPassword.ps1 | Generate a randomized strong password and set on the local Administrator account. Change the password length and user using the variables | [GenerateLocalAdministratorPassword.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/GenerateLocalAdministratorPassword.ps1) |
| Windows | get_dellwarranty.ps1 | This script gathers the Dell Warranty info on the current Dell device. | [get_dellwarranty.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/get_dellwarranty.ps1) |
| Windows | GrantLogonasaService.ps1 | This powershell script grants the Log on as a Service User Rights Assignment to the user specified by the $ServiceAccount param | [GrantLogonasaService.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/GrantLogonasaService.ps1) |
| Windows | map_network_drive.ps1 | Map a network drive | [map_network_drive.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/map_network_drive.ps1) |
| Windows | remove_enrolmentuser_from_localadmins.ps1 | Script to remove the enrolment user from local Administrators group | [remove_enrolmentuser_from_localadmins.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/remove_enrolmentuser_from_localadmins.ps1) |
| Windows | remove_java.ps1 | Delete all Java versions | [remove_java.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/remove_java.ps1) |
| Windows | repurposepc.ps1 | This powershell script Unenrols and then enrols a Windows 10+ device under a different user whilst preserving all WS1 UEM managed applications from being uninstalled upon unenrolment. Maintains Azure AD join status. Does not delete device records from Intune. Downloads AirwatchAgent.msi file to a C:\Recovery\OEM subfolder, creates a Scheduled Task and a script to be run by the Scheduled Task on next logon to repurpose a device to WS1 from one user to another. | [repurposepc.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/repurposepc.ps1) |
| Windows | restart_network_adapter.ps1 | This script restarts all network adapters | [restart_network_adapter.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/restart_network_adapter.ps1) |
| Windows | set_regkeyvalue.ps1 | Set Registry Key | [set_regkeyvalue.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/set_regkeyvalue.ps1) |
| Windows | update_group_policy.ps1 | Forces an Update of the Group Policy Objects applied to this device | [update_group_policy.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/update_group_policy.ps1) |
| Windows | WS1iHubUpdater.ps1 | Downloads and installs the latest Workspace ONE Intelligent Hub using C:\Program Files (x86)\Airwatch\AgentUI\AW.WinPC.Updater.exe | [WS1iHubUpdater.ps1](https://github.com/euc-dev/euc-samples/tree/main/UEM-Samples/Scripts/Windows/WS1iHubUpdater.ps1) |
