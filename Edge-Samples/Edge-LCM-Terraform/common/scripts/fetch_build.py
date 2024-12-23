import sys
import json
import requests
import time
import hashlib
import os

input_data = json.load(sys.stdin)
api_token_url = input_data.get("api_token_url")
refresh_token = input_data.get("refresh_token")
temp_dir = input_data.get("temp_dir")
ovf_api_url = input_data.get("ovf_api_url")

def download_file(url, output_path):
    """Download the file from the given URL to the specified path."""
    with requests.get(url, stream=True) as response:
        response.raise_for_status()
        with open(output_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

def create_token(api_token_url, refresh_token):
    """
    Generates an access token using the provided API URL and refresh token.
    """
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    data = {
        "refresh_token": refresh_token
    }

    try:
        response = requests.post(api_token_url, headers=headers, data=data)
        response.raise_for_status()
        response_data = response.json()
        access_token = response_data.get("access_token")

        # Prepare success result
        result = {"access_token": access_token}
        
        # Write result to fetch_build.json
        with open("fetch_build.json", "w") as file:
            json.dump(result, file, indent=2)
        
        return access_token
    except requests.exceptions.RequestException as e:
        # Prepare error message
        error_message = {"error": f"Token generation failed: {str(e)}"}

        
        # Write error to fetch_build.json
        with open("fetch_build.json", "w") as file:
            json.dump(error_message, file, indent=2)
            
        sys.exit(1)
    except json.JSONDecodeError:
        # Prepare JSON decode error message
        error_message = {"error": "Invalid JSON response during token generation"}
        
        # Write error to fetch_build.json
        with open("fetch_build.json", "w") as file:
            json.dump(error_message, file, indent=2)
        sys.exit(1)

def fetch_ovf_data(api_url, access_token, temp_dir):
    """
    Fetches the OVF data using the access token and API URL.
    """
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json"
    }

    try:
        # Make the API GET request
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        response_data = response.json()
        ovf_path = None
        if isinstance(response_data, list):
            for item in response_data:
                if (
                    isinstance(item, dict) and
                    item.get("fileType") == "OVA" and
                    item.get("capacityType") == "ON_PREM"
                ):
                    ovf_path = item.get("name")
                    ovf_url = item.get("url")
                    expected_md5 = item.get("md5checksum")
                    break

        result = {
            "ovf_path": f"{temp_dir.rstrip('/')}/{ovf_path}",
            "ovf_source": "local"
        } if ovf_path else {"error": "No matching OVA file found"}

        with open("fetch_build.json", "w") as file:
            json.dump(result, file, indent=2)
        print(json.dumps(result))
        attempts = 0
        max_retries = 5
        destination_path = f"{temp_dir.rstrip('/')}/{ovf_path}"
        if os.path.exists(destination_path):
            return
        try:
            download_file(ovf_url, destination_path)
        except requests.exceptions.RequestException as e:
            print(f"Download error: {e}")
            sys.exit(1)

    except requests.exceptions.RequestException as e:
        error_message = {"error": f"Request failed: {str(e)}"}
        with open("fetch_build.json", "w") as file:
            json.dump(error_message, file, indent=2)
        print(json.dumps(error_message))
        sys.exit(1)
    except json.JSONDecodeError:
        error_message = {"error": "Invalid JSON response"}
        with open("fetch_build.json", "w") as file:
            json.dump(error_message, file, indent=2)
        print(json.dumps(error_message))
        sys.exit(1)

access_token = create_token(api_token_url, refresh_token)
fetch_ovf_data(ovf_api_url, access_token, temp_dir)


