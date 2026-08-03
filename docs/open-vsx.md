# Open VSX publishing

Bootprint's editor extension uses the Open VSX identifier [`theworker02.bootprint`](https://open-vsx.org/extension/theworker02/bootprint). Open VSX publication is separate from RubyGems and GitHub Releases.

## One-time account setup

1. Create an [Eclipse account](https://accounts.eclipse.org/user/register) and set its GitHub username to `theworker02`.
2. Sign in to [Open VSX](https://open-vsx.org/) with that same GitHub account.
3. From the Open VSX profile, connect the Eclipse account, read, and accept the Publisher Agreement.
4. Generate a dedicated CI access token from [Open VSX Access Tokens](https://open-vsx.org/user-settings/tokens). Copy it immediately; Open VSX will not show it again.
5. Load the token from a password manager into the trusted workstation's process environment as `OVSX_PAT`, then create the namespace once without placing the token in the command arguments:

   ```console
   npx ovsx create-namespace theworker02
   ```

6. Claim ownership of `theworker02` through the public process documented in the [Open VSX namespace guide](https://github.com/eclipse-openvsx/openvsx/wiki/Namespace-Access). Creating a namespace permits publishing, but claiming it is required for the registry's verified-owner indicator.

Never commit, paste into an issue, or store the token in ordinary project configuration.

## GitHub setup

1. Create a GitHub environment named `open-vsx`.
2. Add an environment secret named `OVSX_PAT` containing a dedicated Open VSX CI token.
3. Add required reviewers to the environment so publication requires explicit approval.
4. Restrict deployment branches or tags to reviewed release refs.

The [Open VSX workflow](../.github/workflows/open-vsx.yml) is manual-only. Running it with `publish` disabled builds and retains a VSIX artifact for review. Running it with `publish` enabled enters the protected environment and uploads the already-tested package.

## Local release gate

```console
cd editors/vscode
npm ci
npm run check
npm run package:vsix
```

Inspect `pkg/bootprint-vscode-VERSION.vsix`, install it into an Open VSX-compatible editor, and test capture, diagnosis, doctor, and verify before publishing. For an intentional manual fallback, provide `OVSX_PAT` only through the process environment and run:

```console
npm run publish:openvsx
```

Do not publish the same version twice. Update `editors/vscode/package.json`, the lockfile, changelog, and documentation before publishing the next version.
