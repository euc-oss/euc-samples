# Programmatically Deletes Google EMM Entitlements

Author: Tae Kim, Omnissa
Last Edit: Apr 18, 2020
Version 1.0  

## Overview
<!-- Summary Start -->
This script programmatically deletes Google EMM Entitlements for all devices at a target WS1 Organization Group.
<!-- Summary End -->

Android Enterprise public application entitlements are managed by Google. Once an app has been entitled for a user, it will remain entitled across all their devices. 

In the case that this app is moved from Public management to Internal management, the public Entitlement will remain. 
The user will still be able to see the app in Play Store > My Work Apps. 
The user will also be prompted to update the app, and can update the app, if a new public version is released.

An app may be moved to Internal management if the customer has a parnership with the app vendor, and receives custom APKs from them. 
The internal app lifecycle management of the app can be bypassed due to the public entitlement still remaining.

This use case is most widely seen on Kiosk type devices. As these devices have unique Google User IDs per device, 
it is acceptable that the entitlement is deleted for all of the target user's devices
