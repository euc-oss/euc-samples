#!/bin/bash

#variables in ws1
# deviceSerial = {DeviceSerialNumber} serial number lookup value
# user = bind svc account username
# pass = bind svc account password
# domain = domain you are binding to
# ws1User = {EnrollmentUser} username lookup value
# adminGroups = AD group names that will allow for admin rights on machine (group1,group2,group3,...)
# orgUnit = OU where device will be bound i.e. OU=MacWorkstations,DC=global,DC=com

#script Variables
logLocation="/Library/Logs/adbind.log"
currentUser=$(stat -f%Su /dev/console)

##### Functions #####

# Logging Function for reporting actions
log() {
    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    LOG="$logLocation"
    echo "$DATE" " $1" >>$LOG
}

#check if logged in user is in admin group
grantLocalAdmin() {
  log "Checking group membership to see if admin rights should be applied"
  #get group membership of user
  checkUserGroups=$(id -Gn "$currentUser")
  log "$currentUser membership: $checkUserGroups"

  #make sure it is a network account
  if [[ "$checkUserGroups" == *"netaccounts"* ]]; then
    log "Network account detected - proceeding"
  else
    log "Not a network account - breaking function"
    return
  fi

  #unable to retrieve membership - break
  if [[ "$checkUserGroups" == "id: $currentUser: no such user" ]]; then
    log "Unable to talk to AD - breaking function"
    log "Removing admin privs from $currentUser as we cannot talk to AD"
    /usr/sbin/dseditgroup -o edit -d "$currentUser" -t user admin
    return
  fi

  #iterate through list looking for match to adminGroups
  matched="no"
  IFS=, read -a Array <<<"$adminGroups"          # this updates IFS only for the duration of 'read'
  for i in "${Array[@]}"; do             # now loop over elements in the array read created
      echo "Group name: ${i}"
      #check for match - grant admin rights
      if [[ "$checkUserGroups" == *"${i}"* ]]; then
        log "Matched on group ${i} - granting local admin"
        /usr/bin/dscl . -append /groups/admin GroupMembership "$currentUser"
        matched="yes"
        break
      fi
  done

  #no match - make sure admin is not applied previously
  if [[ "$matched" == "no" ]]; then
    log "No admin group found for $currentUser"
    log "Ensuring admin privs are not applied to $currentUser"
    /usr/sbin/dseditgroup -o edit -d "$currentUser" -t user admin
    return
  fi
}

#check Allow Administration By directory settings and configure
checkAdminGroups() {
    #check if empty
    if [[ "$adminGroups" == "" ]]; then
      log "Admin Groups not provided as WS1 variable - not configuring this option"
      echo "yes"
      return
    fi
    #check groups set on machine match desired groups
    log "Checking current group configuration with command: dsconfigad -show | grep "Allowed admin groups" | awk 'BEGIN {FS = "="};{print $2}' | sed 's/ //'"
    currentGroups=$(dsconfigad -show | grep "Allowed admin groups" | awk 'BEGIN {FS = "="};{print $2}' | sed 's/ //')
    log "Current groups: $currentGroups"
    log "Desired groups: $adminGroups"
    if [[ "$currentGroups" == "$adminGroups" ]]; then
      log "Admin groups match"
      echo "yes"
    else
      #configure groups
      log "Admin groups do not match. Configuring with command: dsconfigad -groups "$adminGroups""
      response2=$(dsconfigad -groups "$adminGroups")
      log "Admin group config response: $response2"
      if [[ "$response2" == "Settings changed successfully" ]]; then
        log "Admin Groups configured"
        echo "yes"
      else
        log "Admin Groups failed to apply"
        echo "no"
      fi
    fi
}

#check if device is bound to AD and take proper actions
checkADbind() {
  domainCheck=$( dsconfigad -show | awk '/Active Directory Domain/{print $NF}' )
  log "Current AD bind config: $domainCheck"
  log "Desired domain: $domain"
  if [[ "$domainCheck" == "$domain" ]]; then
    log "AD domain is correct"
    # Check the id of a user
    id -u "$ws1User" 1> /dev/null
    log "Checking user against AD"
    # If the check was successful...
    if [[ $? == 0 ]]; then
      log "Bound Correctly - user check passed"
      #check admin groups
      log "Checking admin group configuration"
      checkGroups=$(checkAdminGroups)
      if [[ "$checkGroups" == "yes" ]]; then
        log "Groups configured correctly"
        echo "yes"
      else
        log "Groups not configured correctly"
        echo "nogroups"
      fi
    else
      # If the check failed
      log "Cannot communicate with AD - user check failed"
      echo "no"
    fi
  else
    # If the domain returned did not match our expectations - bind to domain
    log "AD domain is incorrect or not set"
    log "Binding to domain with the command: dsconfigad -a $deviceSerial -u $user -p redacted -ou "$orgUnit" -domain $domain -localhome enable -useuncpath enable -alldomains enable -force"
    response=$(dsconfigad -a $deviceSerial -u $user -p $pass -ou "$orgUnit" -domain $domain -localhome enable -useuncpath enable -alldomains enable -force)
    log "Bind command response: $response"
    if [[ "$response" == "Settings changed successfully" ]]; then
      #echo "Bind Commands Executed Successfully" | tr '\n' ' '
      sleep 10
      #check admin groups
      log "Bind successful - Checking admin group configurations"
      checkGroups=$(checkAdminGroups)
      if [[ "$checkGroups" == "yes" ]]; then
        log "Groups configured correctly"
        echo "yes"
      else
        log "Groups not configured correctly"
        echo "nogroups"
      fi
    else
      #echo "Bind Commands Failed"
      log "Bind unsuccesful"
      echo "no"
    fi
  fi
}

##### Main Code #####

log "##### Starting AD Bind Script #####"
log "### Version 4.1 ###"

#ping the Domain or DC
log "Pinging DC"
ping -c3 -q $domain &>/dev/null

# If the ping was successful
if [[ $? == 0 ]]; then
  log "Successfully reached DC, checking for AD bind"
  checkBind=$(checkADbind)
  grantLocalAdmin
  #check if successful
  if [[ "$checkBind" == "yes" ]]; then
    log "Device bound successfully to AD"
    echo "Device bound successfully to AD"
  elif [[ "$checkBind" == "nogroups" ]]; then
    log "Device bound but admin groups not configured"
    echo "Device bound but admin groups not configured"
  else
    log "Device failed to bind to AD"
    echo "Device failed to bind to AD"
  fi
else
  # cannot talk to a DC
  log "Cannot reach DC, not in range"
  echo "Not in range of a DC"
fi

log "///// Exiting AD Bind Script /////"

exit 0


# Description: Script used to bind device to AD and ensure healthy status throughout device lifecycle
# Execution Context: SYSTEM
# Return Type: STRING
# Variables: deviceSerial,{DeviceSerialNumber}; user,usernameSVC; pass,passwordSVC; domain,test.company.com; ws1User,{EnrollmentUser}; adminGroups,group1; orgUnit,OU=MacWorkstations
