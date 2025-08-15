#!/bin/bash
set -e
exec 2> >(tee -a uagterraform.log >&1)

prefix_name=$1
uag_count=$2
batch_size=$3
ini_file=$4
input_file=$5
error_flag=1

function cleanup {
  if (( $error_flag > 0 ))
  then
    echo "Restoring previous configuration"
    cp main.tf.bak main.tf
  else
    read -p "Do you want to delete the UAGs added in the script? (y/n)" input
    if [[ $input == [yY] ]]
    then
      echo "delete uags"
      terraform destroy -target=module.uag_vsphere_$prefix_name
      cp main.tf.bak main.tf
    fi
  fi
}

if [ -z "$prefix_name" ]
then
  read -p "Enter UAG prefix name: " prefix_name
fi

if [ -z "$uag_count" ]
then
  read -p "Enter number of UAGs to deploy: " uag_count
fi

if [ -z "$batch_size" ]
then
  read -p "Enter the batch size: " batch_size
fi

if [ -z "$ini_file" ]
then
  read -p "Provide the ini file name: " ini_file
fi

if [ -z "$input_file" ]
then
  read -p "Provide the input file name: " input_file
fi

cp main.tf{,.bak}
module_present=$( cat main.tf )
if [[ $module_present != *"uag_vsphere_$prefix_name"* ]]; then
cat <<EOT >> main.tf

module "uag_vsphere_$prefix_name" {
  source = "./uag_vsphere_module"
  uag_name= "$prefix_name"
  uag_count = $uag_count
  iniFile = "$ini_file"
  inputs = "$input_file"
}

output "uag_ipaddress_$prefix_name" {
  value = module.uag_vsphere_$prefix_name.uag_ipaddress
}
EOT
fi

trap cleanup EXIT

#Install the required modules
terraform init

#validate the terraform configuration for any syntax errors
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo "Checking the validity of the Terraform configuration..." | tee -a uagterraform.log
terraform validate | tee -a uagterraform.log
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"


#apply the terraform configuration
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo "Applying the Terraform configuration..." | tee -a uagterraform.log
#Rolling deployment -- if Batch size is less than total count of UAGs, then we use parallelism to specify the number of UAGs to deploy at once
if (( $batch_size < $uag_count ))
then
  terraform apply -target=module.uag_vsphere_$prefix_name -parallelism=$batch_size | tee -a uagterraform.log
else
  terraform apply -target=module.uag_vsphere_$prefix_name | tee -a uagterraform.log
fi
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------+"

#refresh is required to fetch any external changes. Since ip address allocation is an external change, it is required to get the ip address
#get ip address
#run for loop to check if ip address if available
for i in {1..5};
do
  terraform refresh
  uag_ipaddress=$( terraform output uag_ipaddress_"$prefix_name")
  if [[ $uag_ipaddress == *"tostring(null)"* ]];
  then
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
for ip_address in $uag_ipaddress
do
  ip_address=${ip_address%\"*}
  ip_address=${ip_address#\"}
  SSH_COMMAND="ssh root@$ip_address"
  SERVICE_STATUS="supervisorctl status admin esmanager authbroker"

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
  echo "Checking the status of Admin, EsManager and Authbroker services for $ip_address:" | tee -a uagterraform.log
  echo $ssh_output | awk '{print $1 " is " $2}' | tee -a uagterraform.log
  echo $ssh_output | awk '{print $7 " is " $8}' | tee -a uagterraform.log
  echo $ssh_output | awk '{print $13 " is " $14}' | tee -a uagterraform.log
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
done

error_flag=0



