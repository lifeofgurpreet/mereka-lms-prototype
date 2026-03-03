#!/usr/bin/env python3
"""
Create App in App Store Connect via API
"""
import time
from pathlib import Path

import jwt
import requests

API_KEY_ID = "9MUD3HJQH5"
ISSUER_ID = "47ae8cb8-bfa9-49bd-816f-bde34e76d882"
TEAM_ID = "44F7G2D7U6"
BUNDLE_ID = "com.mereka.academy.mobile"
APP_NAME = "Mereka Academy"
SKU = "mereka-academy-ios-001"

API_KEY_PATH = Path("/tmp/api_key.p8")

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
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1"
    }

    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    return token

def get_bundle_id_id():
    """Get Bundle ID ID from identifier"""
    token = generate_jwt_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    url = "https://api.appstoreconnect.apple.com/v1/bundleIds"
    params = {"filter[identifier]": BUNDLE_ID}
    response = requests.get(url, headers=headers, params=params)

    if response.status_code == 200:
        data = response.json()
        if data.get("data"):
            return data["data"][0]["id"]
    return None

def create_app():
    """Create app in App Store Connect"""
    bundle_id_id = get_bundle_id_id()
    if not bundle_id_id:
        print(f"ERROR: Bundle ID '{BUNDLE_ID}' not found")
        return False

    token = generate_jwt_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    url = "https://api.appstoreconnect.apple.com/v1/apps"

    payload = {
        "data": {
            "type": "apps",
            "attributes": {
                "name": APP_NAME,
                "bundleId": BUNDLE_ID,
                "sku": SKU,
                "primaryLocale": "en-US"
            },
            "relationships": {
                "bundleId": {
                    "data": {
                        "type": "bundleIds",
                        "id": bundle_id_id
                    }
                }
            }
        }
    }

    response = requests.post(url, headers=headers, json=payload)

    if response.status_code == 201:
        data = response.json()
        app = data["data"]
        print("✅ App created successfully!")
        print(f"   Name: {app['attributes']['name']}")
        print(f"   Bundle ID: {app['attributes']['bundleId']}")
        print(f"   SKU: {app['attributes']['sku']}")
        return True
    elif response.status_code == 409:
        print("✅ App already exists (409 Conflict)")
        return True
    else:
        print(f"❌ Error creating app: {response.status_code}")
        print(f"   Response: {response.text}")
        return False

if __name__ == "__main__":
    print("Creating App in App Store Connect")
    print("=" * 50)
    print(f"Name: {APP_NAME}")
    print(f"Bundle ID: {BUNDLE_ID}")
    print(f"SKU: {SKU}")
    print("=" * 50)
    print()

    success = create_app()

    if success:
        print("\n✅ Ready to build! Trigger the GitHub Actions workflow.")
    else:
        print("\n❌ Failed to create app. Check error above.")
