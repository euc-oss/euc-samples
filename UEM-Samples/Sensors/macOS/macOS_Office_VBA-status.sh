# Report on Microsoft Office VBA macros status on macOS via a Bash script.
# In Workspace ONE UEM console, create a sensor and paste the below code into the code field.

# Name: macos_office_vbamacros_status
# Language: Bash
# Response: String

current_user=$(ls -l /dev/console | awk '{print $3}')
vba_disabled_value=$(sudo -u $current_user defaults read "/Library/Managed Preferences/com.microsoft.office.plist" | grep "VisualBasicEntirelyDisabled" | awk '{sub(/;/, ""); print $3}')

if [ -z "$vba_disabled_value" ]; then
    echo "Not set"
elif [ "$vba_disabled_value" -eq 1 ]; then
    echo "Disabled"
else
    echo "Enabled"
fi