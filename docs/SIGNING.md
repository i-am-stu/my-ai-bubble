# Signed releases

The public release is Developer ID signed, uses Hardened Runtime and is notarised. Keep the certificate’s private key and notarisation credentials in macOS Keychain, never in this repository.

With a valid Developer ID Application identity and a validated `notarytool` Keychain profile, run:

```sh
DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='your-keychain-profile' NOTARIZE=1 ./scripts/package.sh
```

This builds and signs the app, submits it to Apple, requires acceptance, staples and validates its ticket, then packages and notarises the DMG. It checks both with Gatekeeper and generates checksums after stapling. The ZIP contains the stapled app. Do not publish if any step fails.

Without these variables, build/package scripts produce local ad-hoc builds, which must not be described as notarised. Before publishing, verify the mounted DMG’s app and test a browser download on a separate Mac where possible.
