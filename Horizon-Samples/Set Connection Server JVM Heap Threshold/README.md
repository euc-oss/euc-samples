# Set Connection Server JVM Heap Threshold

Author: Narendran Bunga Jothiram, Omnissa
Last Edit: Jan 20, 2022
Version 1.0

## Overview
<!-- Summary Start -->
This script updates the JVM Heap Memory on a Horizon Connection Server.
<!-- Summary End -->

NOTE: It is highly recommended to test this settings in test environment before applying it to production servers.

Caution: The heap memory can be updated manually in CS_JVMThreshold.bat file only after understanding how it works.  Please get help from Omnissa Global Support if any clarifications before using it.

## Help Menu

`C:\Users\administrator.VIEW>c:\scripts\CS_JVMHeapThreshold.bat -h`

```sh
Utility to set custom JVM threshold values on connection server.
Usage:

    CS_JVMHeapThreshold.bat
        * Updates only the JVM heap settings in registry.
        * Requires manual restart of Connection Server services for heap settings to take effect.
    CS_JVMHeapThreshold.bat -restart
        * Updates only the JVM heap settings in registry.
        * Restarts Horizon Connection Server services automatically after updating the registry
    Use CS_JVMHeapThreshold.bat -h or CS_JVMHeapThreshold.bat -help for help
```

## Usage

`C:\Users\administrator.VIEW>c:\scripts\CS_JVMHeapThreshold.bat`

```sh
The operation completed successfully.
The operation completed successfully.
The operation completed successfully.
```

When the services are in stopping or starting state, script exits and requests for trying again later

`C:\Users\administrator.VIEW>c:\scripts\CS_JVMHeapThreshold.bat -restart`

```sh
The operation completed successfully.
The operation completed successfully.
The operation completed successfully.
Horizon Connection Server Service is not running
The service is starting or stopping.  Please try again later.
```

Services are already in stopped state. JVM heap registry is updated and Script performs start operation

`C:\Users\administrator.VIEW>c:\scripts\CS_JVMHeapThreshold.bat -restart`

```sh
The operation completed successfully.
The operation completed successfully.
The operation completed successfully.
Horizon Connection Server Service is not running
The Horizon View Connection Server service is starting.
The Horizon View Connection Server service was started successfully.
```

Services are in running state, JVM heap registry is updated and Script perform stop and start operation

`C:\Users\administrator.VIEW>c:\scripts\CS_JVMHeapThreshold.bat -restart`

```sh
The operation completed successfully.
The operation completed successfully.
The operation completed successfully.
        STATE              : 4  RUNNING
The Horizon View Connection Server service is stopping....
The Horizon View Connection Server service could not be stopped.

Waiting for sometime before checking status of Horizon Connection Server Service

Waiting for  0 seconds, press a key to continue ...
Waiting for sometime before checking status of Horizon Connection Server Service

Waiting for  0 seconds, press a key to continue ...
        STATE              : 1  STOPPED
Horizon Connection Server Service has stopped
The Horizon View Connection Server service is starting.
The Horizon View Connection Server service was started successfully.
```

