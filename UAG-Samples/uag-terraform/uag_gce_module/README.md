# Prerequisites

1. Terraform : Ensure terraform is installed
   https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli


2. Powershell : Install PowerShell
   https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.5


3. Google Cloud SDK : Install gcloud
   https://cloud.google.com/sdk/docs/install


# Configuration

1. Download zip file : https://github.com/euc-oss/euc-samples
    Unzip the file and go to UAG-Samples/uag-terraform folder and follow below steps.

2. Generate credentials file :
    a. Generate Application Default Credentials file (for local dev)
        gcloud auth application-default login
        It creates the following creds file ~/.config/gcloud/application_default_credentials.json

    b. Generate Service Account Credentials File (recommended for production)
        a. Create service account (optional, if service account exists)
            gcloud iam service-accounts create my-service-account \
            --display-name="My Service Account"

        b. Grant roles to the service account (optional, if roles are assigned)
           gcloud projects add-iam-policy-binding <PROJECT_ID> \
            --member="serviceAccount:my-service-account@<PROJECT_ID>.iam.gserviceaccount.com" \
            --role="<roles>"

        c. Create credentials file 
             gcloud iam service-accounts keys create ~/my-creds.json \
            --iam-account=my-service-account@<PROJECT_ID>.iam.gserviceaccount.com

        d. Export the creds as enviroment variable 
           export GOOGLE_APPLICATION_CREDENTIALS=~/my-creds.json

3. Configure GCE Provider in uag-terraform/main.tf  :  Add projectID and credentials file (creds file need not be added in block if it has been added as environment variable) in the google provider block

        provider "google" {
        project = ""
        credentials = ""
        }

4. Prepare ini file for deploying UAG on GCP : Prepare ini file under uag-terraform folder
   https://docs.omnissa.com/bundle/UAGPowerShellDeploymenttoGoogleCloudPlatformV2303/page/Preparean.iniFileforDeployingUnifiedAccessGatewaytoGoogleCloudPlatform.html

5. Prepare sensitive_inputs.ini file : Add passwords in the sensitive_inputs.ini under uag-terraform folder. The passwords are linked to the module with the uag_name.
uag_hzn and uag_wrp can be replaced with respective UAG names.

        [uag_hzn]
        rootPassword=
        adminPassword=
        awAPIServerPwd=
        awTunnelGatewayAPIServerPwd=
        awCGAPIServerPwd=
        awSEGAPIServerPwd=

        [uag_wrp]
        rootPassword=
        adminPassword=
        awAPIServerPwd=
        awTunnelGatewayAPIServerPwd=
        awCGAPIServerPwd=
        awSEGAPIServerPwd=

6. Add module in uag-terraform/main.tf file for GCP : Multiple modules can be added based on the ini file.
    Replace module_name1/2 with unique names for each module.

        module "<module_name1>" {
        source    = "./uag_gce_module"
        uag_name  = "uag_hzn"
        uag_count = 1
        iniFile   = "uag-horizon.ini" # ini file prepared in step 3
        inputs    = var.sensitive_input
        }

        module "<module_name2>" {
        source    = "./uag_gce_module"
        uag_name  = "uag_wrp"
        uag_count = 1
        iniFile   = "uag-wrp.ini" # ini file prepared in step 3
        inputs    = var.sensitive_input
        }

7. Apply the changes:  
    a. Run terraform init.  
    b. Execute terraform apply -target=module.<module_name1>. This will prompt to provide the sensitive_inputs.ini file; enter the file name and allow the deployment to proceed.  
    c. For the remaining modules, repeat terraform apply -target=module.<module_name2> to deploy UAG in those modules.