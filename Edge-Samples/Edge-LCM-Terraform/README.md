# Horizon Edge Lifecycle Management using Terraform

Version:        0.2
Author:         Srinivas Pinjala, Nancy Jain 
Creation Date:  12/23/2024

## Overview

<!-- Summary Start -->
The Terraform automation samples included in this beta release can be used to create and configure Horizon Edge on Microsoft Azure, AWS EC2 and vSphere
<!-- Summary End -->

## Prerequisites for Azure

### 1.Machine Requirements

A machine running a Linux operating system with the following tools installed:

* Terraform
* Python 3
* pip3
* curl
* unzip
* [AzCopy](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10?tabs=dnf)
* Ensure at least 50GB of free disk space is available

### 2. Install Python Dependencies
The requests package is required for the Python scripts. Install it using the following command:

    ```sh
    pip3 install requests
    ```
    
### 3. Static IP Requirement

A static IP address is required for the Edge VM.

### 4. Configuration File Setup

Copy the sample `config-azure.json` file and update it according to your environment.  
This configuration template must include the following details:

* [Refresh token](https://developer.omnissa.com/horizon-apis/horizon-cloud-nextgen/)
* Microsoft Azure subscription details
* Network and storage information
* Connection Server credentials
* Name of the provider instance 
* Name and fully qualified domain name of the Edge

After deployment, ensure DNS records are [configured](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/ConfigureRequiredDNSRecordsAfterDeployingHorizonEdgeGatewayandUnifiedAccessGateway.html)

### 5. Network Connectivity

Ensure network connectivity is available on the machine running this automation.

## Steps to run this automation for Azure

### 1. Navigate to directory

Change to the `Edge-LCM-Terraform/provider/azure` directory:

    ```sh
    cd provider/azure
    ```
    
### 2. Initialize Terraform 

Run the following command to initialize Terraform:
    
    ```sh
    terraform init 
    ```

### 3. Run Terraform Plan

Execute the terraform plan command. Make sure to pass the operation as "create" and specify the path to the updated `config-azure.json` file using the config_file variable:

    ```sh
    terraform plan -var="operation=create" -var="config_file=/home/testuser/config-azure.json"
    ```

### 4. Run Terraform Apply

Run the terraform apply command with the same configuration as used in the plan step:
 
    terraform apply -var="operation=create" -var="config_file=/home/testuser/config-azure.json"

The apply phase may take 45-60 minutes to complete. For example, the "get_edge_status" step can take up to 30 minutes.

## Prerequisites for AWS EC2

### 1.Machine Requirements

A machine running a Linux operating system with the following tools installed:

* Terraform
* Python 3
* pip3
* curl 

### 2. Install Python Dependencies

The requests package is required for the Python scripts. Install it using the following command:

    ```sh
    pip3 install requests
    ```

### 3. Role and Policy creation in AWS

 Refer to this [document](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/Horizon8Pods-FederatedArchitecturewithCloudonAWSDownloadandDeploytheHorizonEdgeGatewayintoYourEnvironmentinHorizonCloudService-next-gen.html) for creating a role and a policy. After creation, attach the policy to the role.

### 4. Static IP Requirement

A static IP address is required for the Edge VM.

### 5. Configuration File Setup

Copy the sample `config-aws.json` file and update it according to your environment.
This configuration template must include the following details:

* [Refresh token](https://developer.omnissa.com/horizon-apis/horizon-cloud-nextgen/)
* Amazon AWS credentials
* Network and storage information
* Connection Server credentials
* Name of the provider instance 
* Name and fully qualified domain name of the Edge

After deployment, ensure DNS records are [configured](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/ConfigureRequiredDNSRecordsAfterDeployingHorizonEdgeGatewayandUnifiedAccessGateway.html)


### 6. Network Connectivity

Ensure network connectivity is available on the machine running this automation.

## Steps to run this automation for AWS

### 1. Navigate to directory

Change to the `Edge-LCM-Terraform/provider/aws` directory:

    ```sh    
    cd provider/aws
    ```
    
### 2. Initialize Terraform

Run the following command to initialize Terraform:
    
    ```sh
    terraform init
    ```

### 3. Run Terraform Plan

Execute the terraform plan command. Make sure to pass the operation as "create" and specify the path to the updated `config-aws.json` file using the config_file variable:
 
    ```sh
    terraform plan -var="operation=create" -var="config_file=/home/testuser/config-aws.json"
    ```

### 4. Run Terraform Apply

Run the terraform apply command with the same configuration as used in the plan step:
 
    ```sh
    terraform apply -var="operation=create" -var="config_file=/home/testuser/config-aws.json"
    ```

The apply phase may take 45-60 minutes to complete. For example, the "get_edge_status" step can take up to 30 minutes.

## Prerequisites for vSphere

### 1.Machine Requirements

A machine running a Linux operating system with the following tools installed:

* Terraform
* Python 3
* pip3
* curl 

### 2. Install Python Dependencies

The requests package is required for the Python scripts. Install it using the following command:

    ```sh
    pip3 install requests
    ```

### 3. Static IP Requirement

A static IP address is required for the Edge VM.

### 4. Configuration File Setup

Copy the sample `config-vsphere.json` file and update it according to your environment.
This configuration template must include the following details:

* [Refresh token](https://developer.omnissa.com/horizon-apis/horizon-cloud-nextgen/)
* vCenter Server credentials
* Network and storage information
* Connection Server credentials
* Name of the provider instance 
* Name and fully qualified domain name of the Edge

After deployment, ensure DNS records are [configured](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/ConfigureRequiredDNSRecordsAfterDeployingHorizonEdgeGatewayandUnifiedAccessGateway.html)


### 6. Network Connectivity

Ensure network connectivity is available on the machine running this automation.

## Steps to run this automation for vSphere

### 1. Navigate to directory 

Change to the `Edge-LCM-Terraform/provider/vsphere` directory:

    ```sh
    cd provider/vsphere
    ```
    
### 2. Initialize Terraform

Run the following command to initialize Terraform:
    
    ```sh
    terraform init
    ```

### 3. Run Terraform Plan

Execute the terraform plan command. Make sure to pass the operation as "create" and specify the path to the updated `config-vsphere.json` file using the config_file variable:
    
    ```sh 
    terraform plan -var="operation=create" -var="config_file=/home/testuser/config-vsphere.json"
    ```

Note: Terraform's `vsphere_virtual_machine` resource creation expects the ova to be available during the plan phase for validations. Hence, the ova is downloaded during the plan phase.

### 4. Run Terraform Apply

Run the terraform apply command with the same configuration as used in the plan step:
 
    terraform apply -var="operation=create" -var="config_file=/home/testuser/config-vsphere.json"

The apply phase may take 45-60 minutes to complete. For example, the "get_edge_status" step can take up to 30 minutes.

## Known Limitations

### 1. Platform Support

Currently tested only on Ubuntu 22.04.5 LTS (GNU/Linux 6.8.0-49-generic x86_64). Support for Microsoft Windows will be added in a future release. 

### 2. Edge Upgrade

Edge upgrade functionality is not included in this version.

### 3. Edge Binary Download

The Edge binary is downloaded during each automation run. This will be optimized in the next update.

### 4. Temporary JSON Files

A few temporary JSON files are created during the automation run. These files may be automatically managed or removed in future updates.

### 5. Prerequisites checks

Prerequisites checks will be added in the future updates.

### 6. Plan and Apply

Run the plan and apply commands only once for a given configuration. Running them multiple times with the same configuration file may result in resources being marked for destruction.
