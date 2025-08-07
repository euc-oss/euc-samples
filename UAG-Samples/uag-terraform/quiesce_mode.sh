#!/bin/bash

#
# Copyright (c) 2025 Omnissa, LLC.
# -- Omnissa Public
#

prefix_name=$1
admin_passwd=$2
if [ -z "$prefix_name" ]
then
  read -p "Enter UAG prefix name: " prefix_name
fi

if [ -z "$admin_passwd" ]
then
  read -p "Enter UAG Admin password: " admin_passwd
fi

uag_ipaddress=$( terraform output ipaddress_"$prefix_name")
uag_ipaddress=${uag_ipaddress%]*}
uag_ipaddress=${uag_ipaddress##*[}
for ip_address in $uag_ipaddress
do
  ip_address=${ip_address%\"*}
  ip_address=${ip_address#\"}
  echo "$ip_address"
  if [[ $uag_ipaddress == *"tostring(null)"* ]];
  then
    continue
  fi

  json=$(curl -s -X 'GET' \
    'https://'"${ip_address}"':9443/rest/v1/config/system' \
    -H 'accept: application/json' -k -u admin:$admin_passwd)
  quiesce_mode=$(echo "$json" | jq -r .quiesceMode)
  echo "Quiesce Mode: $quiesce_mode"
  if [[ $quiesce_mode == "false" ]]
  then
    updated_json=$(echo "$json" | jq  '.quiesceMode |= true')

    put_request="$(curl -s -X 'PUT' \
      'https://'"${ip_address}"':9443/rest/v1/config/system' \
      -H 'accept: application/json' -H 'Content-Type: application/json' -k -u admin:$admin_passwd -d "${updated_json}")"

    echo "Put Request"
    echo "$put_request"
  fi

  session_count_xml=$(curl -s -X 'GET' \
    'https://'"${ip_address}"':9443/rest/v1/monitor/stats' \
    -H 'accept: application/xml' -k -u admin:$admin_passwd)

  session_count=$( echo "$session_count_xml" | xmlstarlet select --template --value-of /accessPointStatusAndStats/sessionCount --nl)

  echo "Session count: $session_count"
  echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"

done



