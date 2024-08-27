# Add NoMAD configuration

***NOTE:  Add the following Custom XML Payload in a macOS Device-Level profile***

Paste the entire XML snippet (`<dict>...</dict>`) into the Custom XML payload in Workspace ONE UEM.

```xml
<dict>
	<key>PayloadContent</key>
	<dict>
		<key>com.trusourcelabs.NoMAD</key>
		<dict>
			<key>Forced</key>
			<array>
				<dict>
					<key>mcx_preference_settings</key>
					<dict>
						<key>ADDomain</key>
						<string>test.lan</string>
						<key>KerberosRealm</key>
						<string>TEST.LAN</string>
						<key>LocalPasswordSync</key>
						<integer>1</integer>
						<key>RenewTickets</key>
						<integer>1</integer>
						<key>SecondsToRenew</key>
						<integer>3600</integer>
						<key>ShowHome</key>
						<integer>0</integer>
						<key>Template</key>
						<string></string>
						<key>UseKeychain</key>
						<integer>1</integer>
						<key>X509CA</key>
						<string></string>
					</dict>
				</dict>
			</array>
		</dict>
	</dict>
	<key>PayloadEnabled</key>
	<true/>
	<key>PayloadIdentifier</key>
	<string>com.trusourcelabs.NoMAD.170544dd-4fd3-427b-97aa-65b2bd5e7a54.alacarte.customsettings.be5ef7c2-88cd-4af0-9a22-d042a7118f90</string>
	<key>PayloadType</key>
	<string>com.apple.ManagedClient.preferences</string>
	<key>PayloadUUID</key>
	<string>be5ef7c2-88cd-4af0-9a22-d042a7118f90</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
```