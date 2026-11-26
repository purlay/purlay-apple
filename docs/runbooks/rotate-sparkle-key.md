# Rotate Sparkle's EdDSA key

Every installed Mac checks each update against the public key it was built with (`SUPublicEDKey` in `Apps/macOS/Info.plist`). So a
new key reaches Macs only inside an update signed with the **old** key. Rotate only when the old key may be known to someone else,
or by policy; and if the private key is lost, Macs can only be moved by a release signed with it, so keep its backup
([lost-maintainer-access.md](lost-maintainer-access.md)).

1. **Make the new key** on the owner's Mac, with Sparkle's tools (in a Mac Release build's DerivedData:
   `SourcePackages/artifacts/sparkle/Sparkle/bin`): `./generate_keys --account purlay-<year>` prints the public key;
   `./generate_keys --account purlay-<year> -x new-private.key` exports the private one. Keep it in the offline backup.
2. **The transition release** carries the new public key and is signed with the old private key:
   - a pull request sets `SUPublicEDKey` to the new public key and raises the patch version;
   - the release workflow refuses this release as it is: `generate_appcast` does not sign an archive whose app names a different
     key than the one it signs with, and the workflow's check then fails. The transition needs a one-off change to the appcast
     step (sign the archive with `sign_update` and the old key, and verify against it), reviewed in its own pull request and
     reverted after;
   - release it ([release-macos.md](release-macos.md)) and check an update by hand on a Mac with the previous version.
3. **Switch the secret:** `gh secret set SPARKLE_PRIVATE_KEY --env release --repo purlay/purlay-apple < new-private.key`, then
   delete the file. Every later release is signed with the new key, and checked against the new public key.
4. **If the old key leaked,** anyone holding it can sign an update that installed Macs accept, served from the feed's address: keep
   the feed's DNS and Pages locked down (two-factor on the DNS account; the domain verified for the organisation), and do the
   transition release at once.
