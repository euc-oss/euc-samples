# Description: Returns Windows Product Type (e.g. Work Station, Domain Controller, Server)
# Execution Context: SYSTEM
# Execution Architecture: EITHER64OR32BIT
# Return Type: STRING

$os=(Get-CimInstance Win32_OperatingSystem).ProductType

Switch ($os) {
  1 { Return "Work Station" }
  2 { Return "Domain Controller" }
  3 { Return "Server" }
}
