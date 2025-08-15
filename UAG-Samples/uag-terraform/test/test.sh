#!/bin/bash

set -e
exec 2> >(tee -a uagterraform.log >&1)

uag_prefix_name=$1
ini_file=$2
input_file=$3
blue_green=$4
admin_pwd=$5

error_flag=1

function cleanup {
  if (( $error_flag == 0 ))
  then
    terraform -chdir=../ destroy -target=module.uag_vsphere_$uag_prefix_name -var "sensitive_input=$input_file"
  fi
  echo "Restoring previous configuration"
 # rm ../test.tf
}

if [ -z "$uag_prefix_name" ]
then
  read -p "Enter UAG prefix name: " uag_prefix_name
fi

if [ -z "$blue_green" ]
then
  read -p "Do you want blue-green deployment? (y/n) : " blue_green
  if [[ $blue_green == [yY] ]]
  then
    read -p "Enter number of UAGs to deploy in blue pool: " blue_uag_count
    read -p "Enter number of UAGs to deploy in green pool: " green_uag_count
  else
    read -p "Enter number of UAGs to deploy: " uag_count
  fi
fi

if [ -z "$ini_file" ]
then
  read -p "Provide the ini file name: " ini_file
fi

if [ -z "$input_file" ]
then
  read -p "Provide the input file name: " input_file
fi


touch ../test.tf

deploy()
{
prefix_name=$1
count=$2
#uag
cat <<EOT >> ../test.tf

module "uag_vsphere_$prefix_name" {
  source = "./uag_vsphere_module"
  uag_name= "$prefix_name"
  uag_count = $count
  iniFile = "$ini_file"
  inputs = var.sensitive_input
}

output "uag_ipaddress_$prefix_name" {
  value = module.uag_vsphere_$prefix_name.uag_ipaddress
}
EOT

trap cleanup EXIT

#Install the required modules
terraform -chdir=../ init

#validate the terraform configuration for any syntax errors
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo "Checking the validity of the Terraform configuration..." | tee -a uagterraform.log
terraform -chdir=../ validate | tee -a uagterraform.log
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"


#apply the terraform configuration
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo "Applying the Terraform configuration..." | tee -a uagterraform.log

terraform -chdir=../ apply -target=module.uag_vsphere_$prefix_name -var "sensitive_input=$input_file" | tee -a uagterraform.log
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"

#refresh is required to fetch any external changes. Since ip address allocation is an external change, it is required to get the ip address
#get ip address
#run for loop to check if ip address if available
for i in {1..6};
do
  terraform -chdir=../ refresh -var "sensitive_input=$input_file"
  uag_ipaddress=$( terraform -chdir=../ output uag_ipaddress_"$prefix_name")
  if [[ $uag_ipaddress == *"tostring(null)"* ]];
  then
    if [[ $i == 6 ]];
    then
      exit
    fi
    echo "IP Address not yet allotted." | tee -a uagterraform.log
    echo "$uag_ipaddress" | tee -a uagterraform.log
    sleep 60
  else
    echo "IP Address allotted." | tee -a uagterraform.log
    echo "$uag_ipaddress" | tee -a uagterraform.log
    break
  fi
done

uag_ipaddress=${uag_ipaddress%]*}
uag_ipaddress=${uag_ipaddress##*[}

#run loop on each uag to check configuration and health
json='{}'
INDEX=0

for ip_address in $uag_ipaddress
do
  ip_address=${ip_address%\"*}
  ip_address=${ip_address#\"}
  SSH_COMMAND="ssh root@$ip_address"
  SERVICE_STATUS="supervisorctl status admin esmanager"

  echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
  echo "Logging into the machine $ip_address: " | tee -a uagterraform.log
  ssh-keygen -R $ip_address 2>&1 >/dev/null
  ssh_output=$( $SSH_COMMAND $SERVICE_STATUS )

  if [ -z "$ssh_output" ]
  then
    ssh_output=$( $SSH_COMMAND $SERVICE_STATUS 2>&1 >/dev/null )
    if [[ $ssh_output == *"Host key verification failed"* ]];
    then
      ssh-keygen -R $ip_address
      ssh_output=$( $SSH_COMMAND $SERVICE_STATUS )
    fi
  fi

  echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
  echo "Checking the status of Admin, EsManager services for $ip_address:" | tee -a uagterraform.log
  echo $ssh_output | awk '{print $1 " is " $2}' | tee -a uagterraform.log
  echo $ssh_output | awk '{print $7 " is " $8}' | tee -a uagterraform.log
  echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"

#checking the status of admin ui
  ADMIN_UI_STATUS="curl -s -k -I -o /dev/null https://$ip_address:9443/admin/index.html -w "%{http_code}""
  echo "Checking if Admin UI is up and running for $ip_address: " | tee -a uagterraform.log
  response=$( $ADMIN_UI_STATUS )
  if [ "$response" == "200" ]; then
    echo "Admin UI is up and running" | tee -a uagterraform.log
    echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
  else
    echo "Admin UI is not up" | tee -a uagterraform.log
    echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
  fi
  ((INDEX++))
  json="$(
    jq --arg ipaddress "$ip_address" --arg adminpassword "$admin_pwd" --arg index "${INDEX}" '
      .["uag\($index)"] += {$ipaddress, $adminpassword}
    ' <<< "$json"
  )"
done
echo "$json"
}

if [[ $blue_green == [yY] ]]
then
  deploy "$uag_prefix_name"_poolA $blue_uag_count
  deploy "$uag_prefix_name"_poolB $green_uag_count
else
  deploy "$uag_prefix_name" $uag_count
fi

error_flag=0



