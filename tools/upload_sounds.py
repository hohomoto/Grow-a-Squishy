"""Uploads assets/sounds/*.ogg to Roblox and writes the IDs into the game.

One-time setup (about 2 minutes):
  1. Go to https://create.roblox.com/dashboard/credentials and create an
     API key. Add the "Assets" API system with Read and Write, and allow your
     IP address (or 0.0.0.0/0).
  2. Find your user ID (the number in your profile URL), or the group ID if a
     group owns the game.

Then run, from the repo root (Python 3.9+, no extra packages needed):

  python tools/upload_sounds.py --api-key YOUR_KEY --user-id 12345678
  python tools/upload_sounds.py --api-key YOUR_KEY --group-id 87654321

It uploads each sound, waits for Roblox to process it, and fills in
src/shared/Config/Sounds.luau. Uploaded IDs are remembered in
assets/sounds/uploaded.json, so re-running only uploads new or missing ones.
You can also set the key with the ROBLOX_API_KEY environment variable instead
of --api-key, so it doesn't end up in your shell history.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOUNDS_DIR = ROOT / "assets" / "sounds"
CONFIG = ROOT / "src" / "shared" / "Config" / "Sounds.luau"
MEMORY = SOUNDS_DIR / "uploaded.json"
API = "https://apis.roblox.com/assets/v1"

# Config/Sounds.luau key -> file in assets/sounds/
FILES = {
    "Squish": "squish.ogg",
    "Pop": "pop.ogg",
    "Coin": "coin.ogg",
    "Sell": "sell.ogg",
    "Click": "click.ogg",
    "Dig": "dig.ogg",
    "Sparkle": "sparkle.ogg",
    "Star": "star.ogg",
    "Weather": "weather.ogg",
    "Error": "error.ogg",
}


def request(method, url, api_key, body=None, content_type=None):
    headers = {"x-api-key": api_key}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as err:
        detail = err.read().decode(errors="replace")
        sys.exit(f"Roblox returned HTTP {err.code} for {url}:\n{detail}")


def upload(path, api_key, creator):
    meta = {
        "assetType": "Audio",
        "displayName": f"Grow a Squishy - {path.stem}",
        "description": "Sound effect for Grow a Squishy",
        "creationContext": {"creator": creator},
    }
    boundary = uuid.uuid4().hex
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="request"\r\n',
            b"Content-Type: application/json\r\n\r\n",
            json.dumps(meta).encode(),
            f"\r\n--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'.encode(),
            b"Content-Type: audio/ogg\r\n\r\n",
            path.read_bytes(),
            f"\r\n--{boundary}--\r\n".encode(),
        ]
    )
    operation = request("POST", f"{API}/assets", api_key, body, f"multipart/form-data; boundary={boundary}")

    # Uploads finish asynchronously; poll the operation until it's done.
    operation_id = operation.get("operationId") or operation["path"].split("/")[-1]
    for _ in range(60):
        if operation.get("done"):
            break
        time.sleep(2)
        operation = request("GET", f"{API}/operations/{operation_id}", api_key)
    if not operation.get("done"):
        sys.exit(f"Timed out waiting for Roblox to process {path.name}; run the script again later.")
    if "error" in operation:
        sys.exit(f"Roblox rejected {path.name}: {operation['error']}")
    return operation["response"]["assetId"]


def write_config(ids):
    text = CONFIG.read_text()
    for key, asset_id in ids.items():
        pattern = rf'(\t{key} = \{{ id = )"[^"]*"'
        text, count = re.subn(pattern, rf'\1"rbxassetid://{asset_id}"', text)
        if count != 1:
            print(f"warning: couldn't find {key} in {CONFIG.name}; add its ID by hand: {asset_id}")
    CONFIG.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api-key", default=os.environ.get("ROBLOX_API_KEY"))
    owner = parser.add_mutually_exclusive_group(required=True)
    owner.add_argument("--user-id", help="upload as this user")
    owner.add_argument("--group-id", help="upload to this group (if a group owns the game)")
    args = parser.parse_args()
    if not args.api_key:
        sys.exit("Pass --api-key or set ROBLOX_API_KEY.")

    creator = {"userId": args.user_id} if args.user_id else {"groupId": args.group_id}
    uploaded = json.loads(MEMORY.read_text()) if MEMORY.exists() else {}

    for key, filename in FILES.items():
        if key in uploaded:
            print(f"{key:8} already uploaded: {uploaded[key]}")
            continue
        path = SOUNDS_DIR / filename
        print(f"{key:8} uploading {filename} ...", flush=True)
        uploaded[key] = upload(path, args.api_key, creator)
        print(f"{key:8} -> rbxassetid://{uploaded[key]}")
        MEMORY.write_text(json.dumps(uploaded, indent=2) + "\n")

    write_config(uploaded)
    print(f"\nDone. IDs written to {CONFIG.relative_to(ROOT)}. Rebuild or re-sync to hear them.")
    print("New audio can take a few minutes to pass Roblox moderation before it plays.")


if __name__ == "__main__":
    main()
