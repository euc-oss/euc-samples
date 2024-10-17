' This script will alter the AirWatchAgent.msi to include the arguments and parameters for command line enrollment. 
' This altered MSI can be deployed with an AD Software installation GPO for silent enrollment into WS1.

' Change the four values 'SERVER', 'LGNAME', 'USERNAME' and 'PASSWORD' to the correct settings for your Workspace ONE UEM environment.
' Run this script with the name of the AirWatchAgent.msi as argument 

Option Explicit
Dim installer, database, view

Set installer = CreateObject("WindowsInstaller.Installer")
Set database = installer.OpenDatabase (wscript.arguments(0) , 1)

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('ENROLL', 'Y')")
view.Execute
view.Close

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('SERVER', 'ds1108.awmdm.com')")
view.Execute
view.Close

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('LGNAME', 'groupIDxxx')")
view.Execute
view.Close

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('USERNAME', 'staging@td.userxxx.com')")
view.Execute
view.Close

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('PASSWORD', 's3cr3t')")
view.Execute
view.Close

Set view = database.OpenView ("INSERT INTO Property (Property, Value) VALUES ('ASSIGNTOLOGGEDINUSER', 'Y')")
view.Execute
view.Close

database.Commit
Set database = Nothing
Set installer = Nothing
Set view = Nothing