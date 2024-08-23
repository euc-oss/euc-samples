# Configure-or-Customize-Horizon-CS-Logs-with-registry.-Enables-io.netty-logging-on-Connection-Server
<!-- Summary Start -->
This script helps in eliminating manual efforts in updating each of the CS with customized logging. 
<!-- Summary End -->
Please feel free to set a different allowed decimal values for following registry. Name is self explanatory. 

REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDaysKept" /d 10 
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDebugLogs" /d 20 
REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware VDM\Log" /t REG_DWORD /f /v "MaxDebugLogSizeMB" /d 100

log_scripts folder has log4j2.xml and log4j.default which gets replaced. 

Feel free to customize it based on the needs of your horizon environment to enable collection of more useful data required for troubleshooting.

IT is strongly recommended to test this with non production environment, prior to applying it in production.

How to use:

After downloading the file to your local, extract the zip file and navigate to log_scripts folder. 

Copy the entire log_scripts folder to connection server machine. 

Open administrator mode command prompt. Navigate the log_scripts folder or directory where ConfigHorizonLogs.cmd exists.

Execute the command for applying the desire log setting on Connection Server. 

Note: Restart of the service is not required. This has to be performed on each of the CS
