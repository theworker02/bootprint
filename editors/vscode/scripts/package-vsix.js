"use strict";

const childProcess = require("node:child_process");
const path = require("node:path");
const manifest = require("../package.json");

const output = path.join("..", "..", "pkg", `bootprint-vscode-${manifest.version}.vsix`);
const windows = process.platform === "win32";
const executable = windows ? process.execPath : "npx";
const npxArguments = windows
  ? [path.join(path.dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js")]
  : [];
const result = childProcess.spawnSync(
  executable,
  [...npxArguments, "--no-install", "vsce", "package", "--out", output],
  {
    cwd: path.join(__dirname, ".."),
    stdio: "inherit",
    shell: false
  }
);

if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
