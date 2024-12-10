import sys
import json
import requests
import hashlib
import time

def calculate_md5(file_path, chunk_size=8192):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def download_file(url, output_path):
    """Download the file from the given URL to the specified path."""
    with requests.get(url, stream=True) as response:
        response.raise_for_status()
        with open(output_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

input_data = json.load(sys.stdin)
ova_url = input_data["ova_url"]
destination_path = input_data["destination_path"]
expected_md5 = input_data["expected_md5"]
max_retries = input_data.get("max_retries", 6)

attempts = 0
while attempts < max_retries:
    try:
        download_file(ova_url, destination_path)
        file_md5 = calculate_md5(destination_path)
        
        if file_md5 == expected_md5:
            print(json.dumps({"status": "success", "md5": file_md5}))
            break
        else:
            attempts += 1
            print(f"Checksum mismatch (attempt {attempts}/{max_retries}). Retrying...")
            time.sleep(2) 
    except requests.exceptions.RequestException as e:
        print(f"Download error: {e}")
        sys.exit(1)

if attempts == max_retries:
    print(json.dumps({"status": "failed", "error": "MD5 checksum mismatch after max retries"}))
    sys.exit(1)
