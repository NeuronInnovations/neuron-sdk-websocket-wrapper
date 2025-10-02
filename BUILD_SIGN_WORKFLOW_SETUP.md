# GitHub Workflow Setup: Build, Sign, and Release macOS Wrapper

Use this guide to provision repository secrets and trigger the `Build & Sign macOS Wrapper` workflow. The workflow produces signed (and optionally notarized) macOS binaries for both Intel and Apple Silicon, uploads artifacts, and attaches them to GitHub releases.

## 1. Prepare Required Credentials

Collect the following credentials before configuring the repository:

| Purpose                                   | Secret name                   | Notes                                                                                                                                  |
| ----------------------------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Access private Go modules                 | `GH_PAT`                      | Classic personal access token with `repo` scope. Stored only in GitHub Secrets.                                                        |
| Signing identity                          | `MAC_SIGNING_IDENTITY`        | Subject Name or SHA-1 fingerprint as shown by `security find-identity`. Example: `Developer ID Application: Example Corp (ABCDE12345)` |
| Signing certificate                       | `MAC_CERT_P12`                | Base64-encoded `.p12` bundle exported from Keychain containing the signing certificate and private key.                                |
| Certificate password                      | `MAC_CERT_PASSWORD`           | Password used when exporting the `.p12`.                                                                                               |
| Temporary keychain password               | `MAC_KEYCHAIN_PASSWORD`       | Any strong password; used by the workflow to create/ unlock a throwaway keychain.                                                      |
| App Store Connect API key (base64)        | `ASC_API_KEY`                 | Base64-encoded contents of the `.p8` key (see tip below).                                                                              |
| API key identifier                        | `ASC_API_KEY_ID`              | 10-character key ID shown alongside the API key in App Store Connect.                                                                  |
| API key issuer (Team ID)                  | `ASC_API_KEY_ISSUER`          | 10-character issuer ID for your App Store Connect account.                                                                             |
| _Optional fallback_ Apple ID              | `APPLE_ID`                    | Only needed if you prefer legacy Apple ID notarization.                                                                                |
| _Optional fallback_ Team identifier       | `APPLE_TEAM_ID`               | Used with Apple ID fallback authentication.                                                                                            |
| _Optional fallback_ App-specific password | `APPLE_APP_SPECIFIC_PASSWORD` | Used with Apple ID fallback authentication.                                                                                            |

> Tips:
>
> - Base64-encode the `.p12` locally with `base64 -w0 signing-cert.p12 > signing-cert.p12.b64` and paste the result as the `MAC_CERT_P12` secret.
> - Base64-encode the `.p8` App Store Connect key with `base64 -w0 AuthKey_ABC123DEF.p8 > AuthKey_ABC123DEF.p8.b64` and paste it into `ASC_API_KEY`.
> - When using the provided credential templates, see [Populating secrets from credential files](#populating-secrets-from-credential-files).

## 2. Add Secrets to the Repository

1. Navigate to the repository on GitHub.
2. Open **Settings → Secrets and variables → Actions**.
3. Use **New repository secret** to add each secret above. Keep naming exact—case sensitive.
4. For branches that do not require signing (e.g. forks), simply omit the secrets; the workflow will skip signing/notarization automatically.
5. If you still rely on Apple ID notarization, keep the `APPLE_*` secrets in place—otherwise they can be removed.

## 3. Allow GitHub CLI for Releases (Optional)

The workflow uses `gh release upload` when it runs on the `release` event. Ensure the default `GITHUB_TOKEN` has `contents: write` permissions:

1. Go to **Settings → Actions → General**.
2. Under **Workflow permissions**, select **Read and write permissions**.
3. Enable **Allow GitHub Actions to create and approve pull requests** (not required for releases but commonly enabled).

## 4. Trigger Options

### Manual Dispatch (Dry Run)

1. Open **Actions → Build & Sign macOS Wrapper**.
2. Click **Run workflow**.
3. Provide a `tag` (e.g. `v1.2.3-rc1`). This tag is only used for artifact labeling unless the workflow is triggered from a published release.
4. Set `notarize` to `true` or `false`. When set to `true`, notarization only runs if either the App Store Connect API key or the legacy Apple ID secrets are present.
5. Start the run. Artifacts are attached to the workflow run for download/testing.

### Published Release (Production)

1. Create and publish a release (via the GitHub UI or CLI) with the desired tag.
2. Once the release is published, the workflow triggers automatically.
3. After completion, the signed `.zip` files and checksum files are attached to the release.

## 5. Verifying Outputs

After the workflow completes:

- Download the artifacts (from the workflow run or the release assets).
- Verify the stapled binaries locally:
  ```bash
  unzip neuron-wrapper-darwin64.zip
  codesign --verify --verbose neuron-wrapper-darwin64
  spctl --assess --type execute neuron-wrapper-darwin64
  ```
- Confirm the notarization log (`dist/neuron-wrapper-darwin64-notary.json`) reports `Accepted`.

## 6. Troubleshooting

- **Missing secrets**: The workflow step “Configure notarization flag” reports missing secrets in the job summary. Add the App Store Connect API key secrets (or Apple ID fallback values) and rerun.
- **Certificate import errors**: Ensure the `.p12` password matches `MAC_CERT_PASSWORD`, and that the bundle includes the private key.
- **Notarization failures**: Review the JSON log in `dist/*-notary.json` for Apple’s status and message. Common causes include invalid Apple ID credentials or unsigned binaries (check that signing ran successfully).
- **Release upload issues**: Verify repository permissions allow Actions to write release assets and that the release remains published (not drafted) during the run.

## 7. Keeping Credentials Secure

- Rotate the PAT, App Store Connect API key, and any Apple app-specific passwords periodically.
- Restrict repository admin access to limit who can view or modify secrets.
- Remove secrets when no longer needed; the workflow gracefully degrades to unsigned builds.

Once these steps are complete, the pipeline is ready to produce signed, notarized binary releases triggered by either manual runs or new GitHub releases.
