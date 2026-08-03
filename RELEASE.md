# Release process

Bootprint releases are built from an immutable `vVERSION` Git tag and published through RubyGems Trusted Publishing. The workflow uses GitHub OIDC to obtain a short-lived, gem-scoped credential; no long-lived RubyGems API key belongs in GitHub secrets.

## One-time maintainer setup

1. Create the public GitHub repository at `theworker02/bootprint` with `main` as its default branch.
2. Apply the repository controls in [docs/maintainer-setup.md](docs/maintainer-setup.md).
3. Create a RubyGems.org account, enable MFA for UI and API operations, and verify the account email.
4. On RubyGems.org, create a pending trusted publisher for the new `bootprint` gem with:
   - GitHub owner: `theworker02`
   - repository: `bootprint`
   - workflow: `release.yml`
   - environment: `release`
5. In GitHub, create a protected environment named `release`, restrict it to tags matching `v*`, and require a maintainer review before deployment.

RubyGems supports pending trusted publishers for a gem's first release. Recheck that the `bootprint` name is still available immediately before the initial tag is pushed.

## Prepare a release

1. Update `Bootprint::VERSION` in `lib/bootprint/version.rb`.
2. Add a dated entry to `CHANGELOG.md` using the exact version.
3. Update version-specific README text and badges when necessary.
4. Run the full local gate:

   ```console
   bundle install
   bundle exec rake release_check
   ```

5. Inspect and smoke-test the generated package:

   ```console
   gem specification pkg/bootprint-VERSION.gem
   gem install pkg/bootprint-VERSION.gem --install-dir tmp/gem-home --bindir tmp/gem-bin --no-document
   GEM_HOME="$PWD/tmp/gem-home" GEM_PATH="$PWD/tmp/gem-home" tmp/gem-bin/bootprint --version
   ```

6. Audit the staged Git diff for credentials, private snapshots, generated packages, absolute user paths, and unrelated files.
7. Commit the release changes. Do not tag a dirty or unreviewed tree.

## Publish

Create and push a signed tag only after the `main` branch checks pass:

```console
git tag -s vVERSION -m "Bootprint VERSION"
git push origin vVERSION
```

The tag starts `.github/workflows/release.yml`, which:

1. verifies the tag matches `Bootprint::VERSION` and `CHANGELOG.md`;
2. runs tests and RuboCop;
3. builds, installs, and smoke-tests a preflight `.gem` from the tagged source;
4. pauses at the protected `release` environment;
5. prints the release package's SHA-256 digest;
6. rebuilds and publishes through the official RubyGems OIDC action; and
7. creates a GitHub release with that same package attached.

For 0.2.0, use the release title `Bootprint 0.2 — From Environment Differences to Actionable Diagnoses` when editing the generated GitHub release notes.

## Verify after publication

```console
gem install bootprint -v VERSION
bootprint --version
bootprint help
gem owner bootprint
```

Confirm the RubyGems page shows the correct links, MIT license, Ruby requirement, MFA requirement, checksum, owners, and trusted publisher. Confirm the GitHub release attachment has the same SHA-256 digest as the workflow output.

## Build the VS Code package

Keep `editors/vscode/package.json` aligned with the intended extension release version. The extension depends on the Ruby gem at runtime but is versioned and distributed independently.

```console
cd editors/vscode
npm ci
npm run check
npm run package:vsix
code --install-extension ../../pkg/bootprint-vscode-VERSION.vsix
```

Before distributing the VSIX, inspect its contents with `vsce ls`, verify the bundled license and logo, and smoke-test capture and doctor commands in both Bundler and direct-executable modes. Publishing to the Visual Studio Marketplace requires a registered publisher and must be performed separately from the RubyGems release.

## Emergency and manual release policy

Prefer rerunning a failed trusted-publishing job. A manual `gem push` is an emergency fallback only and must use an MFA-protected, least-privilege RubyGems API key from an approved maintainer workstation. Never store that key, an OTP, or a signing private key in the repository, workflow variables, shell history, or issue attachments.

RubyGems certificate signing is optional and separate from signed Git tags and OIDC publishing. If enabled later, keep the private key offline, commit only the public certificate, configure `spec.cert_chain`, and document how consumers verify it before making signed packages mandatory.
