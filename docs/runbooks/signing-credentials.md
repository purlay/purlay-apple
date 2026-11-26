# Renew or replace a signing credential

The Mac's release uses three credentials, all secrets of the `release` environment ([releasing.md](../development/releasing.md)).

| Symptom in the release run | Cause | Section |
|---|---|---|
| "no valid Developer ID Application identity" at the import step | the certificate expired or was revoked | Developer ID certificate |
| `security import` fails | a wrong `MACOS_CERTIFICATE_PASSWORD`, or a P12 that is not base64 | Developer ID certificate |
| notarization: HTTP 401 or "invalid credentials" | the API key was revoked, or a secret is wrong | Notarization key |
| notarization: status `Invalid` | Apple refused the build: read `xcrun notarytool log <submission-id> --key … --key-id … --issuer …` | — |

Put an expiry reminder in the owner's calendar for each credential the day it is made.

## Developer ID certificate (Developer ID Application, valid 5 years)

1. On the owner's Mac, Xcode → Settings → Accounts → the team → *Manage Certificates* → + → *Developer ID Application*.
   (Only the team's Account Holder can create one.)
2. Export it with its key from Keychain Access as a `.p12` with a new password.
3. `base64 -i DeveloperID.p12 | gh secret set MACOS_CERTIFICATE_P12 --env release --repo purlay/purlay-apple` and
   `gh secret set MACOS_CERTIFICATE_PASSWORD --env release --repo purlay/purlay-apple`; delete the `.p12` file. Keep the
   certificate and its key in the owner's offline backup ([lost-maintainer-access.md](lost-maintainer-access.md)).
4. If the old one was compromised, revoke it at developer.apple.com → Certificates. Apps already signed with it keep running;
   their notarization stays valid.
5. Rehearse: `gh workflow run release-macos.yml --ref main -f publish=false`.

The bundle id and the team stay the same, so the Keychain's items and Sparkle's updates continue across certificates.

## Notarization key (App Store Connect API key)

1. App Store Connect → Users and Access → Integrations → Team Keys → + , role *Developer*. Download the `.p8` (it can be
   downloaded once) and note the key id and the issuer id.
2. Check it before storing it: `xcrun notarytool history --key AuthKey_<id>.p8 --key-id <id> --issuer <issuer>`.
3. `base64 -i AuthKey_<id>.p8 | gh secret set APP_STORE_CONNECT_API_KEY_P8 --env release --repo purlay/purlay-apple`, then
   `APP_STORE_CONNECT_KEY_ID` and `APP_STORE_CONNECT_ISSUER_ID` the same way. Keep the `.p8` in the offline backup; delete it
   from the Mac.
4. Revoke the old key in App Store Connect. Rehearse as above.
