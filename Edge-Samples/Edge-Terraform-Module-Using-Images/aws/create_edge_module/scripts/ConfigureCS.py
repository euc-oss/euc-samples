import sys
import json
import requests

# Parse input data from stdin
#deployment_data = json.loads(input_data["cs_configure_data"])  # Decode the json-encoded string

api_url = sys.argv[1]
access_token = sys.argv[2]
org_id = sys.argv[3]
name = sys.argv[4]
viewPodURL = sys.argv[5]
domain = sys.argv[6]
username = sys.argv[7]
password = sys.argv[8]


deployment_data = {
  "providerLabel": "view",
  "orgId" : org_id,
   "name" : name,
  "providerDetails" : {
    "method" : "ByViewConnectionServerCredentials",
    "data" : {
      "viewPodURL" : viewPodURL,
      "authMode" : "PASSWORD",
      "domain" : domain,
      "username" : username,  
      "password" : password,
      "thumbprint" : "",
      "hostNameVerifier" : "false" 
    }
  }
}


# Define request headers
headers = {
    "Accept": "application/json",
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}

def make_patch_request(url, data):
    """Send a PATCH request and return the response."""
    try:
        response = requests.patch(url, headers=headers, data=json.dumps(data))  # Ensure data is serialized again
        return response
    except requests.exceptions.RequestException as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

# If the CS has a CA certificate, the first API call will be successful. 
# However, if the CS has a self-signed certificate, the first API call will fail with a 400 status code and return the thumbprint in the error message. 
# In this case, a second API call is required, where we will send the retrieved thumbprint and invoke the API again.

# 1. First API call to configure CS
response = make_patch_request(api_url, deployment_data)

# Check if response was successful
if response.status_code == 200:
    print(json.dumps({"status": "success", "message" : "", "response_data": response.json()}, indent=2))
    sys.exit(0)
elif response.status_code == 400:
# Handle 400 error and update the payload with the thumbprint
    response_data = response.json()
    print(json.dumps({"status": "error", "message": f"First PATCH Response (400 Error). Status code: {response.status_code}", "response_data": response_data}))
    if response_data:
        thumbprint = response_data["errors"][0]["parameters"].get("thumbprint")
        if thumbprint:
            # Ensure "data" is a dictionary before updating
            if isinstance(deployment_data["providerDetails"]["data"], str):
                deployment_data["providerDetails"]["data"] = json.loads(deployment_data["providerDetails"]["data"])

            # Update the thumbprint
            deployment_data["providerDetails"]["data"]["thumbprint"] = thumbprint

            # Log the updated payload before making the second API call
            print("Second PATCH Request Payload with Thumbprint:", json.dumps(deployment_data, indent=2))

            # 2. Second API call to configure CS with updated thumbprint
            response = make_patch_request(api_url, deployment_data)

            if response.status_code == 200:
                response_str_data = {key : str(value) for key, value in response_data.items()}
                print(json.dumps({"status": "success", "message": f"Success in second PATCH. Status code: {response.status_code}", "response_data": response_data}))        
            else:
                print(json.dumps({"status": "error", "message": f"Unexpected status code in second PATCH. Status code: {response.status_code}", "response_data": response_data}))
                sys.exit(1)
        else:
            print(json.dumps({"status": "error", "message": f"Thumbprint not found in 400 response. Status code: {response.status_code}", "response_data": response_data}))
            sys.exit(1)
    else:
        print(json.dumps({"status": "error", "message": f"Unexpected 400 response format. Status code: {response.status_code}", "response_data": response_data}))
        sys.exit(1)
else:
    print(json.dumps({"status": "error", "message": f"Unexpected status code. Status code: {response.status_code}"}))
    sys.exit(1)
