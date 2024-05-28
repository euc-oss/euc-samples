# UAG Automation and Day 2 Operations

- **Author**: Justin Silva
- **Email**: jsilva@vmware.com
- **Date Created**: 04/26/2021
- **Supported Platforms**: Successfully tested deployment with 3.9.1, 3.10, 2009, 2012 and 2103

## Purpose 
Updated the UAG auto deploy and day 2 operations PowerShell scripting solution to version 12.1 to resolve an issue identified in field testing. Please use this version going forward and check the GitHub for the latest release version in case any updates are made in the future.

UAG Automation Solutions Developed as a proof of concept for providing a basis for developing automation capabilities for Unified Access Gateway appliances in respect to deployment or day 2 operations. The intent is to allow the user to manage the UAG configurations within a simple CSV and then use the script to rapidly deploy, delete, update UAG's in various aspects that the script supports. Not every INI setting is coded into it, but the base is there to expand to suite your needs, you would just modify the 'DEPLOY' based code  sections that focus on building out the INI to use for UAG deploy with what you want and can tie that back to CSV settings using the other code already there as a examples to build off.

## Requirements
* uagdeploy-20.12.0.0-17307559 (if 3.10 or newer UAG being deployed - BE SURE TO USE RIGHT UAG DEPLOY PACKAGE! WRONG VERSION FOR OVA BEING DEPLOYED CAN FAIL)
* uagdeploy-3.9.1.0-15851887 (if UAG 3.9.1 being deployed) - WARNING! Script has not be tested with anything older than 3.9.1 - use at your own risk
* OVFtool 4.4+
* PowerCLI 12.2
* PowerShell 5.1.18362.145+
* find-module Posh-SSH | Install-Module
* 'master-uag-list.csv' - File created with a configuration per row representing a UAG appliance, fill out all information per row and column for each UAG, passwords can be left blank for now with "" and use the script to set the passwords as optional capability
* Also need to permit the uagdeploy.ps1 & uagdeploy.psm1 files to run without promptig of the autodeploy scripts.

## Other suggestions
* Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
* *Unblock-File <full path>uagdeploy.ps1
* Unblock-File <full path>uagdeploy.psm1

## Notes on UAG Network Interface Names
* netInternet (eth0)          - ip0
* netManagementNetwork (eth1) - ip1
* netBackendNetwork (eth2)    - ip2


## Download
Script and settings files at [](https://github.com/LeakyBuffer/UAG-Automation)

