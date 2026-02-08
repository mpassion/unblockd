# Release Guide

## 1) Bump version

Update app version in `Sources/Unblockd/Info.plist`:

```bash
chmod +x scripts/release/bump_version.sh
scripts/release/bump_version.sh 0.9.0
```

This sets:

- `CFBundleShortVersionString` -> `0.9.0`
- `CFBundleVersion` -> incremented build number

## 2) Validate locally

```bash
swift test
swift package plugin --allow-writing-to-package-directory swiftlint
```

## 3) (Optional) Build + sign + notarize locally

```bash
chmod +x scripts/release/build_release_app.sh
scripts/release/build_release_app.sh 0.9.0

chmod +x scripts/release/sign_and_notarize_app.sh
scripts/release/sign_and_notarize_app.sh \
  0.9.0 \
  "Developer ID Application: YOUR_NAME (TEAM_ID)" \
  "unblockd-notary"
```

Outputs:

- `dist/Unblockd-0.9.0.zip`
- `dist/Unblockd-0.9.0.zip.sha256`

## 4) Configure GitHub Actions secrets (for CI notarization)

Set these in `Settings -> Secrets and variables -> Actions`:

- `MACOS_CERT_P12_BASE64`: base64 of `.p12` with `Developer ID Application` cert
- `MACOS_CERT_PASSWORD`: password for `.p12`
- `KEYCHAIN_PASSWORD`: temporary CI keychain password
- `APPLE_CODESIGN_IDENTITY`: full signing identity name, e.g. `Developer ID Application: YOUR_NAME (TEAM_ID)`
- `APPLE_ID`: Apple ID email
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password
- `APPLE_TEAM_ID`: Apple Developer Team ID

If these secrets are missing, release still builds and publishes artifacts, but without notarization.

## 5) Commit + tag

```bash
git add Sources/Unblockd/Info.plist README.md LICENSE scripts .github/workflows/release.yml RELEASE.md
git commit -m "chore(release): prepare v0.9.0"
git tag v0.9.0
git push origin main --tags
```

Tag push triggers GitHub Actions workflow (`.github/workflows/release.yml`) that:

1. runs tests,
2. builds `Unblockd.app`,
3. optionally signs + notarizes app (if secrets are set),
4. publishes `dist/Unblockd-0.9.0.zip` and checksum to GitHub Release.

## 6) Homebrew cask update (tap repo)

Generate cask file from release artifact checksum:

```bash
chmod +x scripts/release/generate_homebrew_cask.sh
scripts/release/generate_homebrew_cask.sh 0.9.0 /path/to/homebrew-tap/Casks/unblockd.rb
```

Then in your tap repo:

```bash
git add Casks/unblockd.rb
git commit -m "unblockd 0.9.0"
git push
```

Install command for users:

```bash
brew install --cask mpassion/tap/unblockd
```
