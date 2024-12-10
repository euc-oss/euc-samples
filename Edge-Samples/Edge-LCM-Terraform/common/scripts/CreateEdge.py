import  sys
import json
import requests



api_url = sys.argv[1]
access_token = sys.argv[2]
name = sys.argv[3]
fqdn = sys.argv[4]
org_id = sys.argv[5]
provider_instance_id = sys.argv[6]


create_edge_payload = {
    "name": name,
    "description": "Edge description",  
    "fqdn": fqdn,
    "enablePrivateEndpoint": False,
    "orgId": org_id,
    "providerInstanceId": provider_instance_id,
    "deploymentModeDetails": {
        "type": "VM"
    },
    "agentMonitoringConfig": {
        "monitoringEnabled": True
    }
}

payload_json = json.dumps(create_edge_payload)
# Headers for the API call
headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {access_token}",
    "Accept": "application/json"
}
try :
    response = requests.post(api_url, headers=headers, data=payload_json)
    response.raise_for_status()
    response_data = response.json()

    response_str_data = {key : str(value) for key, value in response_data.items()}
except requests.exceptions.RequestException as e:
    print(json.dumps({"error" : str(e)}))
    sys.exit(1)
print(json.dumps(response_str_data))

