@echo off
net.exe session 1>NUL 2>NUL || (Echo Run this script in administrator mode. & Exit /b 1)

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDaysKept" /d 10
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDebugLogs" /d 20
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDebugLogSizeMB" /d 100

setlocal
for /f "tokens=2,*" %%a in ('REG QUERY "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM" /V "ServerInstallPath"  ^|findstr /ri "REG_SZ"') do set SERVER_INSTALL_PATH=%%b
REPLACE log4j.default "%SERVER_INSTALL_PATH%"\lib
REPLACE log4j2.xml "%SERVER_INSTALL_PATH%"\lib