<<<<<<< Updated upstream:Horizon-Samples/Omnissa.Horizon.Helper/README.md
# Omnissa.Horizon.Helper Powershell Module
=======
# Omnissa.Hv.Helper Powershell Module
>>>>>>> Stashed changes:Horizon-Samples/VMware.Hv.Helper/README.md
<!-- Summary Start -->
This powershell modules extends the capabilities provided by the `Omnissa.VimAutomation.HorizonView` module. It can Add, create New, Get, Set, Start and Remove Global, Farm and Pool settings.
<!-- Summary End -->

## Prerequisites/Steps to use this module

1. This module only works for Horizon product E.g. Horizon 7.0.2 and later.
2. Install the latest version of Powershell, PowerCLI(6.5) or (later version via psgallery).
<<<<<<< Updated upstream:Horizon-Samples/Omnissa.Horizon.Helper/README.md
3. Import HorizonView module by running: Import-Module Omnissa.VimAutomation.HorizonView.
4. Import "Omnissa.Horizon.Helper" module by running: Import-Module -Name "location of this module" or Get-Module -ListAvailable 'Omnissa.Horizon.Helper' | Import-Module.
5. Get-Command -Module "This module Name" to list all available functions or Get-Command -Module 'Omnissa.Horizon.Helper'.
=======
3. Import HorizonView module by running: Import-Module VMware.VimAutomation.HorizonView.
4. Import "Omnissa.Hv.Helper" module by running: Import-Module -Name "location of this module" or Get-Module -ListAvailable 'VMware.Hv.Helper' | Import-Module.
5. Get-Command -Module "This module Name" to list all available functions or Get-Command -Module 'Omnissa.Hv.Helper'.
>>>>>>> Stashed changes:Horizon-Samples/VMware.Hv.Helper/README.md

## Documentation

Documentation for this module and all its functions can be found in the [PowerCLI](https://developer.omnissa.com/horizon-powercli/) section of the Omnissa Developer Portal.

## Example script to connect ViewAPI service

```
Import-Module Omnissa.VimAutomation.HorizonView

# Connection to view API service
$hvServer = Connect-HVServer -server <connection server IP/FQDN>
$hvServices = $hvserver.ExtensionData

# List Connection Servers
$csList = $hvServices.ConnectionServer.ConnectionServer_List()
```

## Load this module

```
<<<<<<< Updated upstream:Horizon-Samples/Omnissa.Horizon.Helper/README.md
Get-Module -ListAvailable 'Omnissa.Horizon.Helper' | Import-Module
Get-Command -Module 'Omnissa.Horizon.Helper'
=======
Get-Module -ListAvailable 'Omnissa.Hv.Helper' | Import-Module
Get-Command -Module 'Omnissa.Hv.Helper'
>>>>>>> Stashed changes:Horizon-Samples/VMware.Hv.Helper/README.md
```

## Use advanced functions of this module

```
New-HVPool -spec 'path to InstantClone.json file'
```
