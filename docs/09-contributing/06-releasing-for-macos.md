# Releasing for macOS

A macOS release is more than a release-mode Flutter build. The application,
every nested framework, and every dynamic library must be portable and signed;
the release must use Apple's hardened runtime; and a direct download must carry
a notarization ticket that Gatekeeper can verify.

Visual MD keeps these requirements in the repository. The only machine-local
pieces are the Apple signing identity and notarization credentials.

## Choose the distribution route

There are two Apple distribution routes:

- **Developer ID** is for a download from the Visual MD website or GitHub. The
  app is signed with a Developer ID Application certificate, submitted to
  Apple's notary service, and shipped with the accepted ticket stapled to it.
- **Mac App Store** uses Apple Distribution credentials and is sent
  through App Store Connect. App Review replaces the separate notarization
  submission.

The same Runner target supports both. It keeps App Sandbox enabled because the
reader already works through user-authorized files and scoped bookmarks.

## Repository contract

`macos/Runner/Configs/Release.xcconfig` enables hardened runtime and prevents
Xcode from injecting debugger entitlements into a release. The final
entitlements in `macos/Runner/Release.entitlements` allow only sandboxed,
user-selected file access, app-scoped bookmarks, and outbound network access
for remote images and links.

`macos/Runner/PrivacyInfo.xcprivacy` declares no tracking and no collected
data. It declares file-metadata access for the app's own support files and for
folders the reader explicitly selects. The reason codes are Apple's
`C617.1` and `3B52.1`, respectively.

`bin/tools/validate-macos-bundle.sh` checks the built bundle rather than trusting
project settings. Its normal mode accepts a local ad-hoc signature but requires
the release entitlement set, hardened runtime, privacy manifest, portable
Merman library, and valid nested signatures. `--distribution` additionally
requires Developer ID, a signing team, a secure timestamp, a stapled ticket,
and Gatekeeper acceptance.

`bin/tools/validate-macos-archive.sh` checks the archive as well as the app. It
requires an Apple team and signing identity, then requires the embedded Merman
dylib to have a companion dSYM with the same UUID for every architecture. This
catches both Organizer's **No Team Found in Archive** failure and App Store
Connect's Merman symbol warning before upload.

## Prepare this Mac

1. Add the Apple ID enrolled in the paid Developer Program under Xcode Settings
   > Apple Accounts.
2. Use Manage Certificates to create or download an **Apple Distribution**
   certificate for the Mac App Store. Create a **Developer ID Application**
   certificate only when preparing a direct download. Each certificate and its
   private key must both appear in Keychain Access.
3. Open the Runner workspace under the macOS project in Xcode, select the
   Runner target, and select the registered team under Signing & Capabilities.
4. Register the explicit bundle identifier `com.visualmd.visualmd` in the
   developer portal before the first distribution archive.

The repository never stores certificate files, private keys, Apple passwords,
App Store Connect API keys, or a notary keychain profile.

## Build and inspect

Start from generated-state zero so the evidence describes what a new
contributor and CI will produce:

```sh
flutter clean
flutter pub get
bin/tools/beautipass.sh
```

The release app is written to
`build/macos/Build/Products/Release/Visual MD.app`. The normal validation gate
proves its repository-owned contract even before a distribution certificate is
installed.

After Product > Archive, validate the exact archive before opening the
distribution workflow:

```sh
bin/tools/validate-macos-archive.sh \
  "/path/to/Visual MD.xcarchive"
```

## Upload to the Mac App Store

In Xcode, select the Runner target and confirm that Signing & Capabilities uses
the registered team with automatic signing. Choose **Any Mac** as the run
destination, then Product > Archive. Run the archive validator above before
continuing.

Open Organizer, select that exact archive, and choose Distribute App > App
Store Connect > Upload. Xcode resolves the App Store distribution profile and
re-signs the upload as needed. After App Store Connect finishes processing the
build, select it on the macOS version page before adding the version for
review.

## Sign and notarize a direct download

Create an archive from the Runner workspace with Product > Archive. In
Organizer, choose Distribute App, Developer ID, and Upload. Xcode signs the
archive with Developer ID, sends it to Apple's notary service, and staples the
accepted ticket when the workflow completes.

Export that notarized app, then run the stronger audit against the exported
bundle:

```sh
bin/tools/validate-macos-bundle.sh --distribution \
  "/path/to/Visual MD.app"
```

Only package the exact app that passes this command. A ZIP created with
`ditto --keepParent` preserves macOS metadata for a direct download.

## Failure and recovery

An archive without a team was built before the Runner target had a development
team. Assign the team, leave automatic signing enabled for the App Store route,
and create a new archive; changing an existing archive does not repair its
metadata. An ad-hoc signature means the membership exists but this Mac lacks a
usable Apple identity. `get-task-allow` means a debugger entitlement leaked
into the release. A missing `runtime` flag means hardened runtime was disabled.
A failed `stapler` or `spctl` check means a Developer ID export is not yet the
notarized file users should download.

Do not bypass any of those failures with a locally trusted or self-signed
certificate. Install the correct Apple identity, rebuild the archive, inspect
the notary log, and validate the newly exported artifact.

## Authoritative references

- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
- [Apple: Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Flutter: Build and release a macOS app](https://docs.flutter.dev/deployment/macos)
