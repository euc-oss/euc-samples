# Description: Returns "Charging" or "Not Charging" if the battery is charging or not
# Execution Context: SYSTEM
# Execution Architecture: EITHER64OR32BIT
# Return Type: STRING

if ((Get-WmiObject -Class Win32_Battery).count -ne 0) {
    $charge_status = (Get-WmiObject -Class Win32_Battery).batterystatus
    $charging = @(2,6,7,8,9)
    if($charging -contains $charge_status[0] -or $charging -contains $charge_status[1] ) {
	    return "Charging"
	} else {  
	    return "Not Charging"
    }
} else {
	return "No battery found"
}

