#!/usr/bin/env python3
"""
Check Apple Developer account setup via App Store Connect API
Checks if Bundle ID and App already exist
"""
import json
import time
import jwt
import requests
from pathlib import Path

API_KEY_ID = "9MUD3HJQH5"
ISSUER_ID = "47ae8cb8-bfa9-49bd-816f-bde34e76d882"
TEAM_ID = "44F7G2D7U6"
BUNDLE_ID = "com.mereka.academy.mobile"

# Get API key from GitHub secrets or local file
API_KEY_PATH = Path("/tmp/api_key.p8")
if not API_KEY_PATH.exists():
    print("ERROR: API key not found at /tmp/api_key.p8")
    print("Run: cd /home/gurpreet/bbi-meta/mereka-lms && cat /tmp/api_key_base64.txt | base64 -d > /tmp/api_key.p8")
    exit(1)

def generate_jwt_token():
    """Generate JWT token for App Store Connect API"""
    with open(API_KEY_PATH, 'rb') as f:
        private_key = f.read()
    
    headers = {
        "alg": "ES256",
        "kid": API_KEY_ID,
        "typ": "JWT"
    }
    
    payload = {
        "iss": ISSUER_ID,
        "exp": int(time.time()) + 1200,  # 20 minutes
        "aud": "appstoreconnect-v1"
    }
    
    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    return token

def make_api_request(endpoint, params=None):
    """Make authenticated API request"""
    token = generate_jwt_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    url = f"https://api.appstoreconnect.apple.com/v1/{endpoint}"
    response = requests.get(url, headers=headers, params=params)
    
    if response.status_code == 200:
        return response.json()
    elif response.status_code == 404:
        return None
    else:
        print(f"API Error {response.status_code}: {response.text}")
        return None

def check_bundle_ids():
    """Check if Bundle ID exists"""
    print("=== Checking Bundle IDs ===")
    
    # List all bundle IDs
    params = {"filter[identifier]": BUNDLE_ID}
    data = make_api_request("bundleIds", params)
    
    if data and data.get("data"):
        bundle_id = data["data"][0]
        print(f"✅ Bundle ID found: {bundle_id['attributes']['identifier']}")
        print(f"   Name: {bundle_id['attributes']['name']}")
        print(f"   Platform: {bundle_id['attributes']['platform']}")
        return True
    else:
        print(f"❌ Bundle ID '{BUNDLE_ID}' NOT found")
        return False

def check_apps():
    """Check if App exists in App Store Connect"""
    print("\n=== Checking Apps ===")
    
    # First get Bundle ID ID
    params = {"filter[identifier]": BUNDLE_ID}
    bundle_data = make_api_request("bundleIds", params)
    
    if not bundle_data or not bundle_data.get("data"):
        print(f"❌ Cannot check apps - Bundle ID '{BUNDLE_ID}' not found")
        return False
    
    bundle_id_id = bundle_data["data"][0]["id"]
    
    # Check apps with this bundle ID
    params = {"filter[bundleId]": bundle_id_id}
    apps_data = make_api_request("apps", params)
    
    if apps_data and apps_data.get("data"):
        app = apps_data["data"][0]
        print(f"✅ App found: {app['attributes']['name']}")
        print(f"   Bundle ID: {app['attributes']['bundleId']}")
        print(f"   SKU: {app['attributes']['sku']}")
        return True
    else:
        print(f"❌ App with Bundle ID '{BUNDLE_ID}' NOT found in App Store Connect")
        return False

def check_certificates():
    """Check existing certificates"""
    print("\n=== Checking Certificates ===")
    
    params = {"filter[certificateType]": "IOS_DISTRIBUTION"}
    certs_data = make_api_request("certificates", params)
    
    if certs_data and certs_data.get("data"):
        print(f"✅ Found {len(certs_data['data'])} distribution certificate(s):")
        for cert in certs_data["data"]:
            attrs = cert["attributes"]
            print(f"   - {attrs['name']} (Expires: {attrs['expirationDate']})")
        return True
    else:
        print("❌ No distribution certificates found")
        return False

def main():
    print("Checking Apple Developer Account Setup")
    print("=" * 50)
    print(f"Team ID: {TEAM_ID}")
    print(f"Bundle ID: {BUNDLE_ID}")
    print(f"API Key ID: {API_KEY_ID}")
    print("=" * 50)
    print()
    
    bundle_exists = check_bundle_ids()
    app_exists = check_apps()
    certs_exist = check_certificates()
    
    print("\n" + "=" * 50)
    print("SUMMARY:")
    print(f"  Bundle ID exists: {'✅' if bundle_exists else '❌'}")
    print(f"  App exists: {'✅' if app_exists else '❌'}")
    print(f"  Certificates exist: {'✅' if certs_exist else '❌'}")
    print("=" * 50)
    
    if bundle_exists and app_exists:
        print("\n✅ Everything is set up! You can trigger the build.")
    elif bundle_exists:
        print("\n⚠️  Bundle ID exists but App not created in App Store Connect.")
        print("   Create it at: https://appstoreconnect.apple.com → My Apps → +")
    else:
        print("\n⚠️  Bundle ID not found. Create it at:")
        print("   https://developer.apple.com/account → Identifiers → +")

if __name__ == "__main__":
    main()
