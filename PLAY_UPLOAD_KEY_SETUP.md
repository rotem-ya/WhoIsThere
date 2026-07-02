# Google Play upload key (EA:3B) — GitHub Secrets setup

Google Play App Signing requires the AAB to be signed with the **upload key**
registered in Play, whose SHA-1 is:

```
EA:3B:59:B9:2D:4D:F2:58:77:4C:33:55:76:F3:42:46:CC:11:D0:75
```

`build-aab.yml` signs with this key, read from GitHub Secrets. If a build fails
with `UPLOAD_KEYSTORE_BASE64 secret is not set`, add the 4 secrets below.

The key file is **`upload-keystore.jks`** (alias `upload`). Passwords per the
project notes: `123456`. (Use whatever the actual keystore uses if different.)

## Add the secrets (one time)

On a machine that has `upload-keystore.jks`:

```bash
# macOS:
base64 -i upload-keystore.jks | pbcopy
# Linux:
base64 -w0 upload-keystore.jks
```

Then in GitHub → repo **Settings → Secrets and variables → Actions → New
repository secret**, add:

| Secret name | Value |
|---|---|
| `UPLOAD_KEYSTORE_BASE64` | the base64 string from the command above |
| `UPLOAD_KEYSTORE_PASSWORD` | keystore (store) password — e.g. `123456` |
| `UPLOAD_KEY_ALIAS` | `upload` |
| `UPLOAD_KEY_PASSWORD` | key password — e.g. `123456` |

## Verify

Re-run **Build AAB (Google Play)**. The build:
1. fails fast if `UPLOAD_KEYSTORE_BASE64` is missing;
2. after building, asserts the AAB cert SHA-1 is **EA:3B** and fails otherwise.

A green run means the AAB is correctly signed for Play upload.

## If the keystore is lost

In Play Console → **Test and release → App integrity → App signing → Request
upload key reset**, upload a new upload certificate (e.g. the 25:C3 cert at
`android/upload_certificate.pem`), and switch the secrets to that keystore.
Google takes up to ~48h to apply a reset.
