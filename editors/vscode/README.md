# Bootprint for Open VSX Editors

[![Open VSX](https://img.shields.io/open-vsx/v/theworker02/bootprint?label=Open%20VSX&color=6C4FBB)](https://open-vsx.org/extension/theworker02/bootprint)

Run Bootprint environment capture and compatibility diagnosis from VSCodium, Eclipse Theia, and other Open VSX-compatible editors. The extension is a secure adapter around the official [`bootprint` Ruby gem](https://rubygems.org/gems/bootprint); diagnostic logic remains in the gem so CLI, CI, and editor results stay consistent. It remains compatible with VS Code for local VSIX installation.

## Requirements

- VS Code 1.85 or newer
- Ruby 3.1 or newer
- Bootprint in the workspace bundle (recommended), or `gem install bootprint`
- A trusted workspace

## Commands

- **Bootprint: Capture Environment** creates a sanitized snapshot.
- **Bootprint: Diagnose Against Snapshot** selects and compares a snapshot with the current environment.
- **Bootprint: Run Doctor** checks the current Ruby environment.
- **Bootprint: Verify Environment** verifies against `bootprint.lock` or a selected snapshot.
- **Bootprint: Check CLI Installation** confirms that the Ruby CLI is reachable.
- **Bootprint: Show Output** opens the streamed command output.

Snapshot files also provide **Bootprint: Diagnose Against Snapshot** in the Explorer context menu.

## Configuration

Bootprint uses `bundle exec bootprint` by default. Disable `bootprint.useBundler` to use the executable configured by `bootprint.executable`. You can also set a policy path, strict capture privacy, and when the output channel should be revealed.

Commands are spawned directly with argument arrays. The extension does not invoke a shell, execute remediation suggestions, upload snapshots, or read secret values. VS Code disables the extension in untrusted workspaces.

## Build a VSIX

From this directory:

```console
npm install
npm run check
npm run package:vsix
```

The package is written to `pkg/bootprint-vscode-0.2.0.vsix` at the repository root. Install it with:

```console
code --install-extension pkg/bootprint-vscode-0.2.0.vsix
```

## Open VSX distribution

The registry identifier is [`theworker02.bootprint`](https://open-vsx.org/extension/theworker02/bootprint). Once published, install it from an Open VSX-compatible editor's Extensions view or with VSCodium:

```console
codium --install-extension theworker02.bootprint
```

Maintainers should follow [`docs/open-vsx.md`](../../docs/open-vsx.md) for the one-time Eclipse account, publisher agreement, namespace, token, and protected GitHub environment setup. Registry publication is intentionally manual-only.
