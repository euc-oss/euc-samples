@echo off
REM **************************************************************************
REM Disclaimer: Use this script after testing in non production environment
REM @author njothiram
REM **************************************************************************
net.exe session 1>NUL 2>NUL || (Echo Run this script in administrator mode. & Exit /b 1)
setlocal
If $%1$ == $-help$ GOTO HELP
If $%1$ == $-h$ GOTO HELP

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\plugins\wsnm\TomcatService\Params" /t REG_MULTI_SZ /f /v "JvmHeapThresholds" /d "0MB:-Xmx1024m -Dcom.vmware.vdi.SmallPhysMemory=1\09728MB:-Xmx4096m\015872MB:-Xmx6144m\024064MB:-Xmx8192m"
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\plugins\wsnm\TunnelService\Params" /t REG_MULTI_SZ /f /v "JvmHeapThresholds" /d "0MB:-Xmx1024m\09728MB:-Xmx2048m\015872MB:-Xmx4096m\024064MB:-Xmx4096m"
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\plugins\wsnm\MessageBusService\Params" /t REG_MULTI_SZ /f /v "JvmHeapThresholds" /d "0MB:-Xmx1024m\09728MB:-Xmx2048m\015872MB:-Xmx4096m\024064MB:-Xmx4096m"

If $%1$ == $-restart$ GOTO SERVICE
GOTO :EOF

:SERVICESTOPPED
sc query wsbroker | findstr STOPPED
if %ERRORLEVEL% == 2 goto severe1
if %ERRORLEVEL% == 0 goto stopped1
if %ERRORLEVEL% == 1 goto stopping
echo Service status is unknown
goto end
:severe1
echo Services require manual attention!!!
goto end

:stopping
echo Waiting for sometime before checking status of Horizon Connection Server Service
TIMEOUT /T 60
goto SERVICESTOPPED

:stopped1
echo Horizon Connection Server Service has stopped
net start wsbroker
goto end

:SERVICE
sc query wsbroker | findstr RUNNING
if %ERRORLEVEL% == 2 goto severe
if %ERRORLEVEL% == 1 goto stopped
if %ERRORLEVEL% == 0 goto started
echo Service status is unknown
goto end
:severe
echo Services require manual attention!!!
goto end
:started
net stop wsbroker
goto SERVICESTOPPED
:stopped
echo Horizon Connection Server Service is not running
net start wsbroker
goto end




:end
GOTO :EOF

:HELP
Echo Utility to set custom JVM threshold values on connection server.
Echo Usage:
Echo     CS_JVMHeapThreshold.bat
Echo         * Updates only the JVM heap settings in registry. 
Echo         * Requires manual restart of Connection Server services for heap settings to take effect.
Echo     CS_JVMHeapThreshold.bat -restart
Echo         * Updates only the JVM heap settings in registry.
Echo         * Restarts Horizon Connection Server services automatically after updating the registry
Echo     Use CS_JVMHeapThreshold.bat -h or CS_JVMHeapThreshold.bat -help for help
GOTO :EOF