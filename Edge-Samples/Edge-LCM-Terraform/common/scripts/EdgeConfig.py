import sys
import json
import requests


api_url = sys.argv[1]
access_token = sys.argv[2]


headers = {
    "Authorization": f"Bearer {access_token}",
    "Accept": "application/json"
}


try:
    response = requests.get(api_url, headers=headers)
    response.raise_for_status()
    response_data = response.json()

   
    if isinstance(response_data, list):
        response_str_data = {str(index): str(item) for index, item in enumerate(response_data)}
    elif isinstance(response_data, dict):
       
        response_str_data = {key: str(value) for key, value in response_data.items()}
    else:
       
        response_str_data = {"response": str(response_data)}

except requests.exceptions.RequestException as e:
    print(f"Error: {response.status_code} - {response.text}")
    sys.exit(1)

print(json.dumps(response_str_data))
