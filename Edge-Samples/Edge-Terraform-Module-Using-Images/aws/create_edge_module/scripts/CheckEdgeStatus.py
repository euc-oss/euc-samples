import sys
import json
import requests
import time


api_url = sys.argv[1]
access_token = sys.argv[2]
max_retries = int(sys.argv[3])
delay = int(sys.argv[4])

headers = {
    "Authorization": f"Bearer {access_token}",
    "accept": "application/json"
}

try:
    for attempt in range(1, max_retries + 1):
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        response_data = response.json()

        response_str_data = {key: str(value) for key, value in response_data.items()}

 
        if response_str_data.get("status") == "POST_PROVISIONING_CONFIG_IN_PROGRESS":
            print(json.dumps(response_str_data))
            sys.exit(0)
        else:
            print(f"Attempt {attempt}: Status is {response_str_data.get('status')}, retrying in {delay} seconds...")
            time.sleep(delay)

   
    print("Error: Max retries reached without reaching the expected deployment status.")
    sys.exit(1)

except requests.exceptions.RequestException as e:
    print(f"Error: {e}")
    sys.exit(1)
