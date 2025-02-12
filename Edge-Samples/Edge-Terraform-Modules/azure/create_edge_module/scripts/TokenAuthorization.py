import  sys
import json
import requests


api_url = sys.argv[1]
refresh_token = sys.argv[2]


headers = {
    "Content-Type": "application/x-www-form-urlencoded"
}

data = {
    "refresh_token": refresh_token
}

try :
    response = requests.post(api_url, headers=headers, data= data)
    response.raise_for_status()
    response_data = response.json()

    response_str_data = {key : str(value) for key, value in response_data.items()}
except requests.exceptions.RequestException as e:
    print(json.dumps({"error" : str(e)}))
    sys.exit(1)
print(json.dumps(response_str_data))

