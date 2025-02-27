# Description: Returns True/False if device is Intel vPro Enabled or Disabled
# Execution Context: SYSTEM
# Execution Architecture: EITHER64OR32BIT
# Return Type: BOOLEAN

try { $mei = (Get-PnpDevice -FriendlyName "Intel(R) Management Engine Interface*").Status }
catch { return $false }
if($mei -eq "OK") { return $true } else { return $false }
