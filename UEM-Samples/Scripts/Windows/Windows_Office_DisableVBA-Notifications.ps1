# Disable Microsoft Office VBA macros notifications on Windows via a PowerShell script.
# In Workspace ONE UEM console, create a script and paste the below code into the code field.

# Name: Disable VBA notifications for Office
# Run: User context with admin right

# Disabling macros notifications in office apps
# Define the registry key path for each Office application
$officeApplications = @{
    "Excel" = "HKCU\Software\Policies\Microsoft\Office\16.0\Excel\Security"
    "Word" = "HKCU\Software\Policies\Microsoft\Office\16.0\Word\Security"
    "PowerPoint" = "HKCU\Software\Policies\Microsoft\Office\16.0\PowerPoint\Security"
    "Access" = "HKCU\Software\Policies\Microsoft\Office\16.0\Access\Security"
    "Outlook" = "HKCU\Software\Policies\Microsoft\Office\16.0\Outlook\Security"
    "Publisher" = "HKCU\Software\Policies\Microsoft\Office\16.0\Publisher\Security"
    "Visio" = "HKCU\Software\Policies\Microsoft\Office\16.0\Visio\Security"
}

# Define the registry value name and data
# 1=Enable VBA macros, 2=Disable VBA macros with notification, 3=Disable VBA macros except digitally signed, 4=Disable VBA macros without notification
$valueName = "VBAWarnings"
$valueData = 4

# Loop through each Office application and set the registry value
foreach ($app in $officeApplications.GetEnumerator()) {
    $keyPath = $app.Value
    $appName = $app.Key

# Check if the registry key exists
    if (Test-Path "Registry::$keyPath") {
        Set-ItemProperty -Path "Registry::$keyPath" -Name $valueName -Value $valueData
    } else {
# Create the registry key if it doesn't exist
        New-Item -Path "Registry::$keyPath" -Force | Out-Null
        Set-ItemProperty -Path "Registry::$keyPath" -Name $valueName -Value $valueData
    }

    Write-Host "Disabled macros notifications for $appName."
}