# UEM Managed Goldmaster Scripts
<!-- Summary Start -->
This powershell script allows you to easily use Workspace ONE Unified Endpoint Management (UEM) to bring a Gold Master image up the required state.
<!-- Summary End -->
The install_syncml.xml and remove_syncml.xml files are custom CSPs for setting the Windows Update settings. Place these in a profile in UEM, and modify the target version as needed.

## Requirements
 - A Workspace ONE UEM Admin Account that can use basic auth to authenticate into the APIs.
 - The corresponding Workspace ONE UEM API key.
 - Access to the gold image you want to bring up to date.

## Description
When run, the script will:
  1. Enroll the device to UEM using the given credentials.
  2. Ensure all apps and profiles are on the device (there may be reboots in this step as app installs require).
  3. Run windows update as much as is needed to get the device to the desired update state (there may be reboots in this step as Windows update requires).
  4. Unenroll the device, leaving the apps on there.
  5. Uninstall UEM
  6. Delete the device from UEM console

Every one of the above steps is optional, and can be skipped with one of the inbuilt -SkipX flags (i.e. -SkipCleanup doesn't delete the enrollment from the Workspace ONE UEM console).

For example, to run use the following (replacing values with correct environment details):

```
.\GoldMasterEnrollmentPoc.ps1 `
  -ApiUsername "uem-api-username" `
  -ApiPassword "uem-api-password" `
  -UemUrl https://yourUemAddress.com `
  -TenantCode "uem-tenant-code" `
  -EnrollmentUrl https://yourUemEnrollmentUrl.com `
  -EnrollmentUsername "uem-enrollment-username" `
  -EnrollmentPassword "uem-enrollment-password" `
  -EnrollmentOG "uem-enrollment-og" `
  -AgentMsiPath "C:\path\to\AirwatchAgent.msi"
```

If you don't want to enter username and password directly into the script, it also supports using a pscredential object (pass the result of Get-Credential as -ApiCredential).

To control windows updates, we recommend setting custom windows desktop profiles with syncml similar to the provided install.xml and uninstall.xml files (editing as needed for different feature updates and risk tollerance levels). These files are not meant to be exhaustive, and as long as you set a windows update policy that you're happy with then the script will work with it.

## Parameters
    -ApiUsername <String>
        API/Administrator username into UEM. Necessary if -ApiCredential isn't passed in.

    -ApiPassword <String>
        API/Administrator password into UEM. Necessary if -ApiCredential isn't passed in.

    -ApiCredential <PSCredential>
        API/Administrator credential into UEM.

    -UemUrl <String>
        UEM URL to use.

    -TenantCode <String>
        UEM API Tenant Code.

    -EnrollmentUrl <String>
        Enrollment URL if different to the UEM one, defaults to the -UemUrl value

    -EnrollmentUsername <String>
        Enrollment user username

    -EnrollmentPassword <String>
        Enrollment user password

    -EnrollmentOG <String>
        Enrollment organizational group

    -AgentMsiPath <String>
        Path to the AirwatchAgent.msi. Defaults to "AirwatchAgent.msi" in the current directory.

    -SkipEnroll [<SwitchParameter>]
        Don't enroll the device.

    -SkipUpdate [<SwitchParameter>]
        Don't check for apps or profiles, and don't apply windows updates.

    -SkipUnenroll [<SwitchParameter>]
        Don't unenroll the device. (Also sets -SkipUninstall and -SkipCleanup).

    -SkipUninstall [<SwitchParameter>]
        Skip uninstall. This leaves the Workspace ONE Unified Endpoint Management agent on the device in an unenrolled state.

    -SkipCleanup [<SwitchParameter>]
        Skip the cleanup where the device is deleted from the Workspace ONE Unified Endpoint Management console.