import  sys
import json
import requests


api_url = sys.argv[1]
access_token = sys.argv[2]

headers = {
    
    "Authorization": f"Bearer {access_token}",
    "accept" : "application/json"
}

try :
    response = requests.get(api_url, headers=headers)
    response.raise_for_status()
    response_data = response.json()

    response_str_data = {key : str(value) for key, value in response_data.items()}
except requests.exceptions.RequestException as e:
    print(f"Error: {response.status_code} - {response.text}")
    sys.exit(1)
print(json.dumps(response_str_data))

