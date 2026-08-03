"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const manifest = require("../package.json");

if (!process.env.OVSX_PAT) {
  throw new Error("OVSX_PAT is required to publish to Open VSX");
}

const extensionRoot = path.join(__dirname, "..");
const packagePath = path.resolve(extensionRoot, "..", "..", "pkg", `bootprint-vscode-${manifest.version}.vsix`);
if (!fs.existsSync(packagePath)) {
  throw new Error(`VSIX not found at ${packagePath}; run npm run package:vsix first`);
}

const ovsxManifestPath = require.resolve("ovsx/package.json");
const ovsxManifest = require(ovsxManifestPath);
const ovsxEntry = path.resolve(path.dirname(ovsxManifestPath), ovsxManifest.bin.ovsx);
const result = childProcess.spawnSync(
  process.execPath,
  [ovsxEntry, "publish", packagePath],
  {
    cwd: extensionRoot,
    env: process.env,
    stdio: "inherit",
    shell: false
  }
);

if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
