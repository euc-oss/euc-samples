# Description: Report on Microsoft Office VBA macros status on Windows via a PowerShell script.
# Execution Context: SYSTEM
# Execution Architecture: EITHER64OR32BIT
# Return Type: STRING

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
    if ($value.$valueName -eq 1) { return "Disabled" }
    else { return "Enabled" }
}
else { return "Not set" }
}
else { return "Not set" }
