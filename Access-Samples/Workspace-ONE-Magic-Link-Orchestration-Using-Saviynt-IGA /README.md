# Workspace ONE Magic Link Orchestration with Saviynt-IGA

Author: Sivagami Annamalai, VMware; Lucas Chen, VMware
Last Edit: Nov 24, 2021
Version 1.0  

## Overview
<!-- Summary Start -->
This is a sample workflow to onboard Windows desktops with a complex sequence.
<!-- Summary End -->

First impressions are lasting. How about providing a delightful onboarding experience to your new hires even before their start date? This sample provides an example of how you can use the Saviynt IGA platform to orchestrate the Workspace ONE Magic Link functionality for onboarding so that your pre-hire users can get quick and easy access to their Workspace ONE digital workspace through Workspace ONE Intelligent Hub.

More specifically, this sample will demonstrate how to setup the Magic Link and onboarding within Workspace ONE Access and Hub Services and then use Saviynt to generate a link to be sent to a pre-hire using a communication tool of your choice. Here is a demo video of the end experience in action: https://www.youtube.com/watch?v=MReIFlS8z00&ab_channel=VMwareEnd-UserComputing 

## Pre-Requisites

- Cloud hosted tenant of Workspace ONE Access and Hub Services
- Saviynt IGA
- HCM or HR system where pre-hire users and their non-corporate email addresses are listed
- An email communication tool (i.e. SendGrid)

## Workspace ONE Set Up

1. The first thing we'll need to do is to configure your Workspace ONE Access environment to permit Magic Link creation. This can be done by following these steps: https://docs.omnissa.com/en/VMware-Workspace-ONE/services/VMware_Workspace_ONEHub_onboarding_pre-hires/GUID-B141541B-DB6F-4F6D-98DB-9FC02D0D2F68.html
1. Next, you'll need to configure the Token Auth adapter in Workspace ONE Access. This can be done by following these steps: https://docs.omnissa.com/en/VMware-Workspace-ONE/services/VMware_Workspace_ONEHub_onboarding_pre-hires/GUID-7F95F539-47AE-489E-8DE3-80346B834C68.html
1. Lastly, we'll need to configure the default Workspace ONE Access policy so that Workspace ONE Access will accept Magic Link authentication from a user. This can be done by following these steps: https://docs.omnissa.com/en/VMware-Workspace-ONE/services/VMware_Workspace_ONEHub_onboarding_pre-hires/GUID-8CC0FA1E-1F2C-4546-BB0C-8C7C326DA0B4.html  

Once that's complete, we'll move on the Saviynt section and use the IGA system to generate a Magic Link for a new pre-hire user.

## Saviynt IGA Set up

### Creating a Connection:

To create a connection, perform the following steps:

- Go to **ADMIN > Identity Repository > Connections**. The Security System List page will be displayed.
- On the **Connections** tab, click the **Actions** arrow, and then select **Create Connection**.
- Fill in the parameter values to Create New Connection. Use the attached JSON files provided with this sample to fill in the Connection JSON information.  

| Parameter | Sample Values |
| --- | --- |
| Connection Name | Magic Link |
| Connection Description | Connection to Workspace One and Email Service to send Magic Link to Pre Hires |
| Connection Type | REST |
| Status | Enable |
| Connection Json | Copy the contents from ConnectionJsonSample.json |
| CreateAccountJson | Copy the contents from CreateAccountJsonSample.json | 

Next, you'll need to replace the placeholder values in the JSON text with your own attributes listed in the following section.

### Connection Attributes Usage Description

Below gives clarity on various connection attributes used.

- Customproperty1 referenced in the CreateAccountJson stores the personal email address of the worker received from HR system to which the magic link needs to be sent. Replace custompropery1 with the attribute you use to store personal email address of the worker.
- Customproperty2 referenced in the CreateAccountJson stores the Active Directory samaccountname of the worker. Replace custompropery2 with the attribute you use to store Active Directory samaccountname of the worker.
- wsAuth in Connection Json describes the json format to authenticate against the Workspace One APIs. Replace your Workspace One URL, Client ID and Client Secret for the connection to be successful. For the accessToken attribute, you can put a placeholder string, Saviynt will automatically replace the correct access token when a task is executed.
- emailServiceAuth in Connection Json describes json format to authenticate against the internal email delivery service used. You can plug in with any other REST API that you use to send emails. If you don't have any internal email delivery service, you can explore something like SendGrid email API which is available - https://sendgrid.com/solutions/email-api/ 
- Both Call1 and Call2 URL in CreateAccountJson has conditions to validate if customproperty2 (AD samaccountname), customproperty1 (user's personal email address) and email is not null before calling the actual API endpoint. If any one of the values are null, the task errors out and stays in pending task. You can add multiple conditions as per your business need before calling the API endpoint.
- Call1 in CreateAccountJson actually generates the magic link calling the Workspace One APIs and stores it in the variable - ${response.call1.message.loginLink}if the call is successful. Use this variable in call2 to retrieve the magic link generated. Replace your Workspace URL and domain value inside httpParams according to your environment.
- Call2 in CreateAccountJson uses sample internal email delivery service which sends the generated magic link to the user's personal email address. REST endpoint in Call2 accepts parameters like recipient's email address to which the email needs to be sent, from address, pre-defined html template (Saviynt-PreHireMagicLinkDistribution-Template) that needs to be used & the values of parameters like magiclink, firstname, username, email which will be replaced in the html template pre-defined and sends out the email to the intended recipient when called. Replace Call2 logic with your REST API endpoint URL and request parameters that you use to send emails.
 
### Creating a Security System

To create a security system, perform the following steps:

- Go to **ADMIN > Identity Repository > Security Systems**. The Security System List page will be displayed.
- On the **Security System** tab, click the **Actions** arrow, and then select **Create Security System**. The Create New Security System page is displayed.
- Fill in the parameter values to Create New Security System. 

| Parameter | Sample Values |
| --- | --- |
| System Name * | Magic Link |
| Display Name * | Magic Link |
| Provisioning Connection | Magic Link |
| Default System | No |
| Automated Provisioning | Yes |
| Use Open Connector | No |
| Recon Application | No |
| Instant Provisioning | No |

## Creating an Endpoint

To create an endpoint, perform the following steps:

- Go to **ADMIN > Identity Repository > Security Systems > Endpoints**. The Endpoint List page will be displayed.
- On the Endpoints tab, click the **Actions** arrow, and then select Create Application. The **Create New Endpoint** page is displayed.
- Fill in the parameter values to Create New Endpoint. 

| Parameter | Sample Values |
| --- | --- |
| Endpoint Name * | Magic Link |
| Display Name * | Magic Link |
| Application Name | Magic Link |
| Requestable | OFF |

### Creating Provisioning Rules

- Create a technical rule to provision **Magic Link** application account as birth right for new users based on your business logic.
- Create another technical rule and make sure you add the user to the Active directory group (Example: cn=wsone _limited_access, ,ou=yourou,dc=yourdomain,dc=com) that is used in Workspace one Onboarding template config, if their start date is in future. Make sure **Birthright** and **Remove Birthright Access if condition fails** checkboxes in the rule are marked.
- Create an user update rule to make sure AD group referenced in above point - wsone _limited_access gets removed on the user's start date. You can use **Revoke Selected Access** action and remove the AD group - wsone _limited_access.
- Create an user update rule to make sure Magic Link Account is deprovisioned when the user is terminated.
 

### Scheduling Provisioning Jobs

- Create a trigger for running WSRETRY Job for **Magic Link Security System** - ADMIN > JOB CONTROL PANEL > CREATE NEW JOB > WSRETRY JOB.
- Schedule the created trigger to run every **X** hours according to your requirement to provision Magic Link pending tasks.
 
## Conclusion

Once all that is done, Saviynt will start checking with your HR systems to identify new pre-hire users, generate a Magic Link in Workspace ONE Access, and email the Magic Link to the email address of your pre-hires!