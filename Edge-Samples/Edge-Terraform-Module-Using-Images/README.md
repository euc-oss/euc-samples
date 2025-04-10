# Horizon Edge Lifecycle Management using a Terraform Module using existing images

Version:        0.1
Author:         Srinivas Pinjala, Nancy Jain 
Creation Date:  02/12/2025

## Overview

<!-- Summary Start -->
The Terraform automation samples included in this beta release provides a module that can be used to create and configure Horizon Edge on Microsoft Azure and AWS using the existing Edge image present in the Compute Gallery and AMI.
This automation assumes Azure and AWS Provider is already initialized and Edge image is present in the Compute Gallery and AMI. 
<!-- Summary End -->

## Prerequisites for Azure

### 1.Machine Requirements

A machine running a Linux operating system with the following tools installed:

* Terraform
* Python 3
* pip3

### 2. Install Python Dependencies
The requests package is required for the Python scripts. Install it using the following command:

    ```sh
    pip3 install requests
    ```
    
### 3. Static IP Requirement

A static IP address is required for the Edge VM.

### 4. Configuration Setup

`example/main.tf ` has the sample code to call the Edge deployment module for azure. Update the parameters according to your environment.  
The parameters include :

* [Refresh token](https://developer.omnissa.com/horizon-apis/horizon-cloud-nextgen/)
* Network and storage information
* Connection Server credentials
* Name of the provider instance 
* Name and fully qualified domain name of the Edge

After deployment, ensure DNS records are [configured](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/ConfigureRequiredDNSRecordsAfterDeployingHorizonEdgeGatewayandUnifiedAccessGateway.html)

### 5. Network Connectivity

Ensure network connectivity is available on the machine running this automation.

## Steps to run this automation on Azure

### 1. Navigate to directory

Change to the `Edge-Terraform-Module-Using-Images/azure/example` directory:

    ```sh
    cd Edge-Terraform-Module-Using-Images/azure/example
    ```

### 2. Update the parameters in `main.tf` by referring to `Edge-Terraform-Module-Using-Images/azure/create_edge_module/variables.tf`

    
### 3. Initialize Terraform 

Run the following command to initialize Terraform:
    
    ```sh
    terraform init 
    ```

### 3. Run Terraform Plan

Execute the terraform plan command. 

    ```sh
    terraform plan
    ```

### 4. Run Terraform Apply

Run the terraform apply command with the same configuration as used in the plan step:
 
    terraform apply 

The apply phase may take 45-60 minutes to complete. For example, the "get_edge_status" step can take up to 30 minutes.

## Prerequisites for AWS EC2

### 1.Machine Requirements

A machine running a Linux operating system with the following tools installed:

* Terraform
* Python 3
* pip3

### 2. Install Python Dependencies

The requests package is required for the Python scripts. Install it using the following command:

    ```sh
    pip3 install requests
    ```

### 3. Role and Policy creation in AWS

 Refer to this [document](https://docs.omnissa.com/bundle/HorizonCloudServicesUsingNextGenGuide/page/Horizon8Pods-FederatedArchitecturewithCloudonAWSDownloadandDeploytheHorizonEdgeGatewayintoYourEnvironmentinHorizonCloudService-next-gen.html) for creating a role and a policy. After creation, attach the policy to the role.

### 4. Static IP Requirement

A static IP address is required for the Edge VM.


### 5. Network Connectivity

Ensure network connectivity is available on the machine running this automation.

## Steps to run this automation on AWS

### 1. Navigate to directory

Change to the `Edge-Terraform-Module-Using-Images/aws/example` directory:

    ```sh    
    cd Edge-Terraform-Module-Using-Images/aws/example
    ```
    
### 2. Update the parameters in `main.tf` by referring to `Edge-Terraform-Module-Using-Images/aws/create_edge_module/variables.tf`

### 3. Initialize Terraform

Run the following command to initialize Terraform:
    
    ```sh
    terraform init
    ```

### 4. Run Terraform Plan

Execute the terraform plan command:
 
    ```sh
    terraform plan
    ```

### 5. Run Terraform Apply

Run the terraform apply command with the same configuration as used in the plan step:
 
    ```sh
    terraform apply
    ```

The apply phase may take 45-60 minutes to complete. For example, the "get_edge_status" step can take up to 30 minutes.

