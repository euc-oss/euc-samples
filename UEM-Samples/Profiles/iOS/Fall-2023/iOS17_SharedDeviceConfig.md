# iOS 17 Shared Device Configuration command #

Paste the entire XML snippet (`<dict>...</dict>`) into the [Custom Command](https://docs.omnissa.com/en/VMware-Workspace-ONE-UEM/2011/tvOS_Platform/GUID-AWT-CUST-COMMAND.html) prompt in Workspace ONE UEM.

```xml
<dict>
  <key>RequestType</key>
  <string>Settings</string>
  <key>Settings</key>
  <array>
    <dict>
      <key>Item</key>
      <string>SharedDeviceConfiguration</string>
      <key>QuotaSize</key>
      <integer>2048</integer>
      <key>PasscodePolicy</key>
      <dict>
        <key>AutoLockTime</key>
        <integer>300</integer>
        <key>PasscodeLockGracePeriod</key>
        <integer>14400</integer>
      </dict>
    </dict>
  </array>
</dict>
```

## Key Descriptions ##

| Key              | type      | Presence   | Description                      |
|------------------|-----------|------------|----------------------------------|
|`QuotaSize`   | [integer]   | optional | The quota size, in megabytes (MB), for each user on the shared device, or if the quota size is too small, the minimum quota size. Available to Temporary Sessions Only guest users on iOS 17+.      |
|`AutoLockTime`   |  [integer]   | optional | The number of seconds before a device goes to sleep after being idle. The minimum value for this setting is 120 seconds. Available on iOS 17+.      |
|`PasscodeLockGracePeriod`   |  [integer]   | optional | The number of seconds before a locked screen requires the user to enter the device passcode to unlock it. The minimum value is 0 seconds and the maximum value is 14400 seconds. If a device has a passcode, a change to a larger value doesn't take effect until the user logs out or removes the passcode. For this reason, it's better to set this value before the user sets a passcode. If the value is less than one of the known values, the device uses the next lowest value. For example a value of 299 results in an effective setting of 60. This setting won't take effect if TemporarySessionOnly is true because there's no passcode for a temporary session. Possible Values: 0, 60, 300, 900, 3600, 14400. Available on iOS 17+.      |
