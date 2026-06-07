#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Upload the WhoIsThere store listing (texts + graphics) to Google Play Console
via the Android Publisher API — no browser needed.

Requires a Google Cloud SERVICE ACCOUNT json key that has been granted access
in Play Console (Users & permissions → invite the service-account email →
grant "Edit store listing" on the app). The service account must belong to a
project with the "Google Play Android Developer API" enabled, and the account
must be linked under Play Console → Setup → API access.

Usage:
    python3 upload_to_play_console.py /path/to/service-account.json
    # or:  export PLAY_SA_KEY=/path/to/key.json && python3 upload_to_play_console.py

What it does:
    1. opens an edit
    2. sets he-IL listing: title / short / full description
    3. uploads icon, feature graphic, and the 4 phone screenshots
       (clears existing images of each type first)
    4. validates, then commits the edit (changes go live on the listing)
"""
import os
import sys
import glob

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE = "com.whoisthere.app"
LANG = "he-IL"
ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "google-play-assets")
TEXTS = os.path.join(ASSETS, "texts")
GFX = os.path.join(ASSETS, "graphics")
SHOTS = os.path.join(GFX, "screenshots")
SCOPE = ["https://www.googleapis.com/auth/androidpublisher"]


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def main():
    key = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("PLAY_SA_KEY")
    if not key or not os.path.exists(key):
        sys.exit("ERROR: provide the service-account json path as arg or PLAY_SA_KEY env var.")

    creds = service_account.Credentials.from_service_account_file(key, scopes=SCOPE)
    svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = svc.edits()

    print(f"• opening edit for {PACKAGE} …")
    edit_id = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
    print(f"  edit id: {edit_id}")

    # 1) texts ---------------------------------------------------------------
    title = read(os.path.join(TEXTS, "app_title.txt"))
    short = read(os.path.join(TEXTS, "short_description.txt"))
    full = read(os.path.join(TEXTS, "full_description.txt"))
    assert len(title) <= 30 and len(short) <= 80 and len(full) <= 4000, "text over limit"
    print(f"• updating {LANG} listing text (title {len(title)}, short {len(short)}, full {len(full)}) …")
    edits.listings().update(
        packageName=PACKAGE, editId=edit_id, language=LANG,
        body={"title": title, "shortDescription": short, "fullDescription": full},
    ).execute()

    # 2) graphics ------------------------------------------------------------
    uploads = [
        ("icon", [os.path.join(GFX, "icon_512x512.png")]),
        ("featureGraphic", [os.path.join(GFX, "feature_graphic_1024x500.png")]),
        ("phoneScreenshots", sorted(glob.glob(os.path.join(SHOTS, "phone_screenshot_*.png")))),
    ]
    for image_type, files in uploads:
        files = [f for f in files if os.path.exists(f)]
        if not files:
            print(f"  ! no files for {image_type}, skipping")
            continue
        print(f"• clearing existing {image_type} …")
        edits.images().deleteall(
            packageName=PACKAGE, editId=edit_id, language=LANG, imageType=image_type
        ).execute()
        for fp in files:
            media = MediaFileUpload(fp, mimetype="image/png")
            edits.images().upload(
                packageName=PACKAGE, editId=edit_id, language=LANG,
                imageType=image_type, media_body=media,
            ).execute()
            print(f"    uploaded {image_type}: {os.path.basename(fp)}")

    # 3) validate + commit ---------------------------------------------------
    print("• validating edit …")
    edits.validate(packageName=PACKAGE, editId=edit_id).execute()
    print("• committing edit …")
    edits.commit(packageName=PACKAGE, editId=edit_id).execute()
    print("\n✅ DONE — store listing texts & graphics published to Play Console.")
    print("   (Verify in Play Console → Main store listing.)")


if __name__ == "__main__":
    main()
