# Description: Returns friendly name of the Monitor
# Execution Context: SYSTEM
# Execution Architecture: EITHER64OR32BIT
# Return Type: STRING

$Name = (Get-WmiObject win32_desktopmonitor).Name
return $Name
