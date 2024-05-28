# Add Active Directory Schema Extensions to Azure AD Connect

Azure AD Connect allows to extend the schema in Microsoft Azure AD with attributes from on-premise Active Directory. Not all Active Directory attributes are accessible in Directory Extensions wizard.

Provided scrips allow to manually add directory extensions to Azure AD and Azure AD Connect connector schema.

## How to use

* run: `Add-Extension-Property-To-Azure-AD.ps1 -ApplicationName "My application" -PropertyName property1` to add directory extension to Azure AD,
* on machine where Azure AD Connect is installed run: `Add-Attribute-To-Azure-Connector-Schema.ps1 -AttributeName full_extension_name`, full_extension_name is provided by first script output,
* open the "Synchronization Service Manager", and then "Connectors" tab,
* right-click on Azure AD connector, select "Properties", switch to the "Select attributes" tab, check "Show all" box, find added attribute, select it and save,
* attribute can be used in Synchronisation Rules Editor.


`Delete-Extension-Property-From-Azure-AD.ps1` and `Delete-Attribute-From-Azure-Connector-Schema.ps1` scripts can be used to rollback changes.

More information about directory extensions: https://learn.microsoft.com/en-us/azure/active-directory/hybrid/connect/how-to-connect-sync-feature-directory-extensions.

Verified with Azure AD Connect V2 2.2.8.0 and PowerShell 5.1.14393.1944.