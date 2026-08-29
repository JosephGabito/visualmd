# Releasing for Windows

A Windows release is the complete Flutter bundle inside one signed installer.
The loose `visualmd.exe` is not a distributable by itself: it needs the Flutter
engine, native plugin libraries, compiled Dart application, fonts, and assets
that the Windows build places beside it.

## The two release lanes

The ordinary **Validate** workflow builds and audits an unsigned Windows x64
bundle for every pull request and push to `main`. That proves the repository
still compiles on the real Windows toolchain without exposing a private key.

The **Release Windows** workflow has two entry points:

- A manual run creates an unsigned installer for QA. It is deliberately not
  published as a GitHub release. Its one-day workflow artifact is named
  `UNSIGNED-QA-DO-NOT-DISTRIBUTE` so it cannot be mistaken for the product.
- A `v<version>` tag creates the public artifact. The tag must match the build
  name in `pubspec.yaml`, identify a commit reachable from `main`, and pass the
  protected `windows-release` environment before signing can begin.

The workflow pins Flutter 3.47.1, Inno Setup 6.7.3, and every top-level GitHub
Action to an immutable commit. It analyzes, tests, builds, audits, installs,
launches, reinstalls, uninstalls, signs, packages, rechecks the publisher and
timestamp, writes a SHA-256 file, records GitHub build provenance, and only
then creates the release (`.github/workflows/release-windows.yml`).

## Signing identity

Public tags use Microsoft Azure Artifact Signing, Microsoft's recommended
service for apps distributed outside the Store. GitHub authenticates with OIDC,
so no certificate file, private key, or Azure client secret enters the
repository or runner.

Create an Artifact Signing account and public-trust certificate profile, grant
the federated GitHub identity the **Artifact Signing Certificate Profile
Signer** role, and create a protected GitHub Actions environment named
`windows-release`. The Azure federated credential should trust the environment
subject `repo:JosephGabito/visualmd:environment:windows-release`, not every tag
or workflow in the repository.

Add these Actions variables to that environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_ARTIFACT_SIGNING_ENDPOINT`
- `AZURE_ARTIFACT_SIGNING_ACCOUNT`
- `AZURE_ARTIFACT_SIGNING_PROFILE`
- `WINDOWS_SIGNER_SUBJECT` — the complete stable certificate subject expected
  from `Get-AuthenticodeSignature`, such as `CN=Your verified publisher name`

The workflow requests `id-token: write` solely inside the protected publication
job. Missing variables, an unexpected publisher, or a missing RFC 3161
timestamp stop the release before publication. Inno Setup invokes the same
signer while compiling, so both the outer installer and its installed
`unins000.exe` carry the expected publisher.

Microsoft currently limits Public Trust identity validation to the
jurisdictions listed in its
[Artifact Signing prerequisites](https://learn.microsoft.com/en-us/azure/artifact-signing/quickstart#prerequisites).
Confirm the legal entity and billing identity are eligible before depending on
this release lane. A private-trust or test profile is not a substitute for a
public download; if Public Trust is unavailable, use another publicly trusted
Authenticode provider and preserve the same publisher, timestamp, and
installer-lifecycle gates.

## Local QA installer

On Windows with Visual Studio and Inno Setup installed:

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build windows --release
bin/tools/validate-windows-bundle.ps1 -ExpectedVersion 1.0.0
$installer = bin/tools/package-windows.ps1
bin/tools/test-windows-installer.ps1 `
  -InstallerPath $installer `
  -ExpectedVersion 1.0.0
bin/tools/write-windows-checksum.ps1 -InstallerPath $installer
```

Run the lifecycle command only in a clean VM, snapshot, or CI runner. It refuses
to start when Visual MD is already installed because its purpose is to install,
reinstall, and uninstall the production application identity.

Install the pinned packaging tool with:

```powershell
winget install --id JRSoftware.InnoSetup -e --version 6.7.3 `
  --source winget --accept-package-agreements --accept-source-agreements
```

The installer and checksum are written under `dist\windows`. A local QA build
is unsigned by design and may trigger SmartScreen; it is evidence about
packaging and behavior, not a public artifact.

## Public release

Update `version:` in `pubspec.yaml`, commit the release, and wait for the normal
Validate workflow to pass. Protect the `v*.*.*` tag pattern and require approval
on the `windows-release` environment. Then create and push the matching tag:

```powershell
git tag -a v1.0.0 -m "Visual MD 1.0.0"
git push origin v1.0.0
```

Do not reuse a version or move a published tag. Windows installer upgrades
depend on the stable application ID in `windows/installer/visualmd.iss`, while
release provenance depends on the tag continuing to identify one commit.
The workflow first uploads both release files to a draft and only then makes it
public. It refuses to replace an existing release or asset. If a failed run
leaves a draft behind, inspect and delete that draft before deliberately
rerunning the tag workflow.

## Clean-machine evidence

Before announcing the download, use a fresh Windows 11 snapshot:

1. Verify the `.sha256` file against the downloaded installer.
2. Confirm Properties → Digital Signatures reports the expected publisher.
3. Install without administrator elevation and launch from the Start Menu.
4. Open the sample, pick a folder, drop a folder and one Markdown file, and
   follow an external link.
5. Save a workspace, restart, and confirm restoration and live file refresh.
6. Install a newer test version to exercise cross-version upgrade behavior.
7. Uninstall from Windows Settings and confirm the application directory and
   shortcuts are removed. User-created Markdown and exported workspaces must
   remain untouched.

CI already installs, launches, reinstalls, rejects stale owned DLLs, verifies
the signed uninstaller, and uninstalls on a fresh Windows runner. This manual
pass proves what automation cannot see: Windows trust UI, native integration,
the workspace write channel, and the experience a reader receives.
