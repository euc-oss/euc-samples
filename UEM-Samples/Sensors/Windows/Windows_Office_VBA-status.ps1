# Report on Microsoft Office VBA macros status on Windows via a PowerShell script.
# In Workspace ONE UEM console, create a sensor and paste the below code into the code field.

# Name: win_office_vbamacros_status
# Run: System context

# This script checks the status of the vbaoff setting on Windows
# Define the registry key variables
$keyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common"
$valueName = "vbaoff"

# Check if the registry key path exists
if (Test-Path $keyPath) {
# Get the value of the registry value
$value = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
# Check if the value is not null (i.e., the value exists)
if ($value -ne $null) {
# Check if the value is set to 1
    if ($value.$valueName -eq 1) { Write-Output "Disabled" }
    else { Write-Output "Enabled" }
}
else { Write-Output "Not set" }
}
else { Write-Output "Not set" }