Import-module ActiveDirectory
$objects = Get-ADObject -LDAPFilter "(&(objectClass=pae-Prop)(pae-NameValuePair=alwaysConnect*))" -SearchBase "OU=Properties,DC=vdi,DC=vmware,DC=int" -Properties distinguishedName,pae-NameValuePair -server localhost:389
if ($objects -ne $null) {
    foreach ($obj in $objects) {
        if ($obj.distinguishedName -ne $null)  {
            Set-ADObject -Identity $obj.distinguishedName -server localhost:389 -Remove @{'pae-NameValuePair'="alwaysConnect=1"}
            Set-ADObject -Identity $obj.distinguishedName -server localhost:389 -Remove @{'pae-NameValuePair'="alwaysConnect=true"}
        }
    }
}