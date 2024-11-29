# Disable Microsoft Office VBA macros on macOS via a custom profile.
In Workspace ONE UEM console, create a custom profile and paste the below code into the custom settings field.

Configuration reference: https://learn.microsoft.com/en-us/deployoffice/mac/set-preference-macro-security-office-for-mac

```
<dict>
	<key>PayloadDisplayName</key>
	<string>Microsoft Office settings</string>
	<key>PayloadIdentifier</key>
	<string>com.microsoft.office.4164F689-9190-4094-A869-CE04C288947B</string>
	<key>PayloadType</key>
	<string>com.microsoft.office</string>
	<key>PayloadUUID</key>
	<string>4164F689-9190-4094-A869-CE04C288947B</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
	<key>VisualBasicEntirelyDisabled</key>
	<true/>
	<key>VisualBasicMacroExecutionState</key>
	<string>DisabledWithoutWarnings</string>
</dict>
```