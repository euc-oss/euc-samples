# Disable Connection Server Auto-Reconnect to AD

Author: Narendran Jothiram, Omnissa
Last Edit: Sep 17, 2022
Version 1.0  

## Overview
<!-- Summary Start -->
Disables Connection Server auto-reconnect to AD.
<!-- Summary End -->
When end users are using Auto connect feature on the client side, it leads to sending multiple session requests. 

To modify the settings of user client in horizon database, the attached script would help in resetting the auto connect feature to get disabled for all the users having client connected information in horizon local database.

How to execute:

> Login to horizon connection server machine using RDP
> Open PowerShell as Administrator and use the snippet in this sample for resetting the values in the horizon database.