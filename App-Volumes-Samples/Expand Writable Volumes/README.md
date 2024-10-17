# Expand-WV

Version:        1.0  
Author:         Chris Halstead, Omnissa
Creation Date:  4/8/2019  
Purpose/Change: Initial script development  

## Overview
<!-- Summary Start -->
Script to update the size of App Volumes Writable Volumes.  Can also be used to view sizes of volumes.  
<!-- Summary End -->
New sizes won't be reflected until a user logs in and attaches the Writable Volume	
Outputs log file stored in %temp%\expand-wv.log>

## Usage

```
.\Expand-WV.ps1
  -AppVolumesServerFQDN "avmanager.company.com"
  -AppVolumesDomain "mydomain"
  -AppVolumesUser "Username"
  -AppVolumesPassword "SecurePassword"
  -New_Size_In_MB "40960"
  -Update_WV_Size "yes"
```

### Parameters
`AppVolumesServerFQDN`  
The FQDN of the App Volumes Manager where you want to view / change the Writable Volumes
    
`AppVolumesDomain`  
Active Directory Domain of the user with Administrative access
    
`AppVolumesUser`  
Active Directoty User with administrative access
    
`AppVolumesPassword`  
The password that is used by the user specified in the username parameter
    
`New_Size_In_MB`  
New size for the writable volumes in Megabytes. Take gigabytes and mutltiply by 1024.
    
`Update_WV_Size`  
Enter yes to update the sizes.  Type anything else for a list of writable volumes.