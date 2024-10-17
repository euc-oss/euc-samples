# Unprotect Instant Clone VMs

Author: Mark McGill, VMware
Last Edit: 11-23-2020
Version 1.1

## Overview
<!-- Summary Start -->
Unprotect Instant Clone VMs in order to delete those that are abandoned by Horizon. Uses vCenter API to enable methods needed to unprotect Instant Clone VMs. Enabled methods match those enabled by the Horizon icCleanup tool to unprotect Instant Clones.
<!-- Summary End -->

## Requirements
PowerCLI and Powershell 5.

## Usage  
Load function in order to call
`. .\Unprotect-InstantClone.ps1`

Required parameters are vm and vCenter  
`Unprotect-InstantClone -vm <vmName> -vCenter <vcenterFQDN>`

Accepts pipeline input in the form of an array of VM Names, or VM Objects from Get-VM  
`$vms = Get-VM ic-Template*`
`$vms | Unprotect-InstantClone -vCenter <vcenterFQDN> -user administrator@vsphere.local`

Username and password can be passed as parameters as well as a Credential object.  You will be prompted if none are provided  
`$credentials = Get-Credential`  
`Unprotect-InstantClone -vm <vmName> -vCenter vCenter.corp.local -Credentials $credentials`

You will be prompted to confirm unprotecting VMs unless you pass the '-Confirm $false' parameter  
`Unprotect-InstantClone -vm <vmName> -vCenter <vcenterFQDN> -user administrator@vsphere.local -Confirm $false`

Use the '-Verbose' option to show additional output during processing  
`Unprotect-InstantClone -VM <vmName> -vCenter <vcenterFQDN>  -Verbose`