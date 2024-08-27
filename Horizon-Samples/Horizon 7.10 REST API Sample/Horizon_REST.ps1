<#
.SYNOPSIS
Horizon 7.10 REST API Sample
Only works on Horizon 7.10 and later

.NOTES
  Version:        1.0
  Author:         Chris Halstead - chalstead@vmware.com
  Creation Date:  10/9/2019
  Purpose/Change: Initial script development
  
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function LogintoHorizon {

#Get data and save to variables
$script:HorizonServer = Read-Host -Prompt 'Enter the Horizon Server Name'
$Username = Read-Host -Prompt 'Enter the Username'
$Password = Read-Host -Prompt 'Enter the Password' -AsSecureString
$domain = Read-Host -Prompt 'Enter the Domain'

#Convert the Password
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

#Construct JSON to pass to login endpoint
$Credentials = '{"username":"' + $username + '","password":"' + $unsecurepassword + '","domain":"' + $domain + '"}'

#Retrieve JSON Web Token
Write-Host "Getting JWT From: $HorizonServer"

try {
    
    $sresult = Invoke-RestMethod -Method Post -Uri "https://$horizonserver/rest/login" -Body $Credentials -ContentType "application/json"
}

catch {

  Write-Host "An error occurred when logging on to Horizon $_"
  break 
}

#Save the returned JSON Web Token to a Global Variable
$script:JWToken = $sresult.access_token

Write-Host "Successfully Logged In"

  } 
Function GetCS {

#Check if the user is logged in
if ([string]::IsNullOrEmpty($JWToken))
    {
      write-host "You are not logged into Horizon"
      break   
    }

Write-Host "Getting Connection Servers for: $horizonserver"

#Create header with JSON Web Token
$bearerAuthValue = "Bearer $JWToken"
$headers = @{ Authorization = $bearerAuthValue }  


try{$cs = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/connection-servers" -Headers $headers -ContentType "application/json"
        }
            catch {
                  Write-Host "An error occurred when getting connection servers $_"
                  break 
                  }

$cs | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Status'; Expression = {$_.status}},@{Name = 'Connection Count'; Expression = {$_.Connection_Count}},`
@{Name = 'Certificate Valid'; Expression = {$_.Certificate.valid}}
 
}   

Function GetFarms {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting Farm Data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
  
  
  try{$farm = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/farms" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting farm data $_"
                    break 
                    }
  
$farm | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Status'; Expression = {$_.status}},@{Name = 'RDS Server Count'; Expression = {$_.rds_server_count}},`
@{Name = 'Published Apps'; Expression = {$_.application_count}},@{Name = 'Farm Type'; Expression = {$_.details.type}}
  
}

Function GetRDS {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting RDS Data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
  
  
  try{$rds = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/rds-servers" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting RDS server data $_"
                    break 
                    }
  
$rds | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Status'; Expression = {$_.status}},@{Name = 'Enabled'; Expression = {$_.enabled}},`
@{Name = 'Session Count'; Expression = {$_.session_count}},@{Name = 'OS'; Expression = {$_.details.operating_system}},@{Name = 'Agent'; Expression = {$_.details.agent_version}},`
@{Name = 'State'; Expression = {$_.details.state}}
  
}

Function GetEventDB {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting Events Database Data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
  
  
  try{$edb = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/event-database" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting events db data $_"
                    break 
                    }
  
if($edb.status -eq "NOT_CONFIGURED")
{
  write-host "The Events Database is not set up"
  break   
}

$edb | Format-table -AutoSize -Property @{Name = 'DB Server'; Expression = {$_.details.server_name}},@{Name = 'Prefix'; Expression = {$_.details.Prefix}},@{Name = 'Status'; Expression = {$_.status}},`
@{Name = 'Number Events'; Expression = {$_.event_count}}
  
}

Function GetAD {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting AD Domain Data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
    
try{$addata = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/ad-domains" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting AD domains data $_"
                    break 
                    }
  
$addata | Format-table -AutoSize -Property @{Name = 'Netbios Name'; Expression = {$_.netbios_name}},@{Name = 'DNS Name'; Expression = {$_.dns_name}},@{Name = 'NT4 Domain'; Expression = {$_.nt4_domain}}
  
}

Function GetUAG {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting UAG Data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
    
  try{$uag = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/gateways" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting UAG data $_"
                    break 
                    }
  if($UAG.length -eq 0)
        {
          write-host "There is no UAG data."
          break   
        }
  
$UAG | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Status'; Expression = {$_.status}},@{Name = 'Active Connections'; Expression = {$_.active_connection_count}},`
@{Name = 'IP'; Expression = {$_.details.address}},@{Name = 'Version'; Expression = {$_.details.version}}
  
}
Function GetSAML {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting SAML data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
    
  try{$saml = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/saml-authenticators" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting SAML data $_"
                    break 
                    }
  if($saml.length -eq 0)
        {
          write-host "There is no SAML data."
          break   
        }
  
$saml | Format-table -AutoSize -Property @{Name = 'Label'; Expression = {$_.details.label}}

}

Function GetComp {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting Composer Server data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
    
  try{$comp = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/view-composers" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting Composer data $_"
                    break 
                    }
  if($comp.length -eq 0)
        {
          write-host "There is no Composer Server data."
          break   
        }
  
$comp | format-list
  
}
Function GetVC {

  #Check if the user is logged in
  if ([string]::IsNullOrEmpty($JWToken))
      {
        write-host "You are not logged into Horizon"
        break   
      }
  
  Write-Host "Getting Virtual Center data for: $horizonserver"
  
  #Create header with JSON Web Token
  $bearerAuthValue = "Bearer $JWToken"
  $headers = @{ Authorization = $bearerAuthValue }  
    
  try{$vc = Invoke-RestMethod -Method Get -Uri "https://$horizonserver/rest/monitor/virtual-centers" -Headers $headers -ContentType "application/json"}
              catch {
                    Write-Host "An error occurred when getting Virtual Center data $_"
                    break 
                    }
  
$vc | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Version'; Expression = {$_.details.version}},@{Name = 'API Version'; Expression = {$_.details.api_version}}

  
}

function Show-Menu
  {
    param (
          [string]$Title = 'Horizon REST API Menu'
          )
       Clear-Host
       Write-Host "================ $Title ================"
             
       Write-Host "Press '1' to Login to Horizon"
       Write-Host "Press '2' for Connection Servers"
       Write-Host "Press '3' for Farms"
       Write-Host "Press '4' for RDS Servers"
       Write-Host "Press '5' for Events Information"
       Write-Host "Press '6' for AD Domains"
       Write-Host "Press '7' for UAG Information"
       Write-Host "Press '8' for SAML Authenticators"
       Write-Host "Press '9' for Composer Servers"
       Write-Host "Press '10' for Virtual Centers"
       Write-Host "Press 'Q' to quit."
         }

#-----------------------------------------------------------[Execution]------------------------------------------------------------
do
 {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    switch ($selection)
    {
    
    '1' {  

         LogintoHorizon

        } 
    
    '2' {
   
         GetCS

        } 
    
    '3' {
       
        GetFarms
      
        }

   
    '4' {
       
        GetRDS  

        }

  '5' {
       
        GetEventDB
  
      }


'6' {
       
        GetAD
    
  }

'7' {
       
        GetUAG
    
  }

  '8' {
       
        GetSAML
      
    }

  '9' {
       
      GetComp
    
  }

  
  '10' {
       
      GetVC
  
}

    }
    pause
 }
 until ($selection -eq 'q')


Write-Host "Finished"