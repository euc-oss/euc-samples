import  sys
import json
import requests

create_provider_url = sys.argv[1]
access_token = sys.argv[2]
org_id = sys.argv[3]
geo_location_lat = sys.argv[4]
geo_location_long = sys.argv[5]
name = sys.argv[6]
provider_type = sys.argv[7]
is_federated = sys.argv[8]


create_provider_payload = {
    "providerLabel": "view",
    "name": name,  
    "description": "Provider Instance description",
    "orgId": org_id,
    "providerDetails": {
        "method": "ByViewConnectionServerCredentials",
        "data": {
            "viewProviderType": provider_type,
            "isFederatedArchitectureType": is_federated,
            "geoLocationLat": geo_location_lat,
            "geoLocationLong": geo_location_long,
        }
    }
}


payload_json = json.dumps(create_provider_payload)


headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {access_token}",
    "accept": "application/json"
}


try :
    response = requests.post(create_provider_url, headers=headers, data= payload_json)
    response.raise_for_status()
    response_data = response.json()

    response_str_data = {key : str(value) for key, value in response_data.items()}
except requests.exceptions.RequestException as e:
    print(json.dumps({"error" : str(e)}))
    sys.exit(1)
print(json.dumps(response_str_data))

