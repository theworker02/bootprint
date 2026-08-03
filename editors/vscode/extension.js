"use strict";

const childProcess = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const vscode = require("vscode");
const { commandSpec, displayCommand, withPolicy } = require("./src/command");

let output;
let status;

function activate(context) {
  output = vscode.window.createOutputChannel("Bootprint");
  status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
  status.name = "Bootprint";
  status.text = "$(shield) Bootprint";
  status.tooltip = "Run Bootprint Doctor";
  status.command = "bootprint.doctor";
  status.show();

  context.subscriptions.push(
    output,
    status,
    register("bootprint.capture", capture),
    register("bootprint.diagnose", diagnose),
    register("bootprint.doctor", () => runBootprint(["doctor"])),
    register("bootprint.verify", verify),
    register("bootprint.checkInstallation", checkInstallation),
    register("bootprint.openOutput", () => output.show(true))
  );
}

function register(command, callback) {
  return vscode.commands.registerCommand(command, async (...argumentsList) => {
    try {
      await callback(...argumentsList);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      output.appendLine(`Bootprint extension error: ${message}`);
      output.show(true);
      await vscode.window.showErrorMessage(`Bootprint: ${message}`);
    }
  });
}

async function capture() {
  const label = await vscode.window.showInputBox({
    title: "Capture a Bootprint environment snapshot",
    prompt: "Snapshot label",
    value: "local",
    validateInput: (value) => /^[A-Za-z0-9._-]+$/.test(value)
      ? undefined
      : "Use letters, numbers, dots, underscores, or hyphens."
  });
  if (!label) return;

  const privacy = configuration().get("privacy", "standard");
  const result = await runBootprint(["capture", label, "--privacy", privacy], { applyPolicy: true });
  if (result.code === 0) {
    await vscode.commands.executeCommand("workbench.files.action.refreshFilesExplorer");
  }
}

async function diagnose(resource) {
  const snapshot = resource instanceof vscode.Uri ? resource : await selectSnapshot("Select a Bootprint snapshot to diagnose against");
  if (!snapshot) return;
  await runBootprint(["diagnose", "--against", snapshot.fsPath], { applyPolicy: true });
}

async function verify() {
  const root = workspaceRoot();
  const defaultSnapshot = path.join(root, "bootprint.lock");
  const snapshot = fs.existsSync(defaultSnapshot)
    ? vscode.Uri.file(defaultSnapshot)
    : await selectSnapshot("Select the reference snapshot to verify against");
  if (!snapshot) return;
  await runBootprint(["verify", "--against", snapshot.fsPath], { applyPolicy: true });
}

async function checkInstallation() {
  const result = await runBootprint(["--version"], { applyPolicy: false });
  if (result.code === 0) {
    await vscode.window.showInformationMessage("Bootprint CLI is available in this workspace.");
  }
}

async function selectSnapshot(title) {
  const selections = await vscode.window.showOpenDialog({
    title,
    canSelectMany: false,
    canSelectFiles: true,
    canSelectFolders: false,
    defaultUri: vscode.Uri.file(workspaceRoot()),
    filters: { "Bootprint snapshots": ["json", "lock"], "All files": ["*"] }
  });
  return selections && selections[0];
}

function configuration() {
  return vscode.workspace.getConfiguration("bootprint");
}

function workspaceRoot() {
  if (!vscode.workspace.isTrusted) {
    throw new Error("Trust this workspace before running its Ruby dependencies.");
  }
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  if (!folder) throw new Error("Open a Ruby project folder before running Bootprint.");
  return folder.uri.fsPath;
}

function runBootprint(argumentsList, options = {}) {
  const root = workspaceRoot();
  const settings = configuration();
  const spec = commandSpec({
    useBundler: settings.get("useBundler", true),
    executable: settings.get("executable", "bootprint")
  });
  const commandArguments = options.applyPolicy === false
    ? argumentsList
    : withPolicy(argumentsList, settings.get("policyPath", ""), root);
  const completeArguments = [...spec.prefixArguments, ...commandArguments];

  output.appendLine("");
  output.appendLine(`> ${displayCommand(spec.executable, completeArguments)}`);
  if (settings.get("revealOutput", "always") === "always") output.show(true);
  status.text = "$(sync~spin) Bootprint";

  return new Promise((resolve, reject) => {
    let settled = false;
    const processHandle = childProcess.spawn(spec.executable, completeArguments, {
      cwd: root,
      env: process.env,
      shell: false,
      windowsHide: true
    });

    processHandle.stdout.on("data", (chunk) => output.append(chunk.toString()));
    processHandle.stderr.on("data", (chunk) => output.append(chunk.toString()));
    processHandle.on("error", (error) => {
      settled = true;
      status.text = "$(error) Bootprint";
      reject(new Error(`${error.message}. Install the bootprint gem or update Bootprint settings.`));
    });
    processHandle.on("close", async (code) => {
      if (settled) return;
      settled = true;
      status.text = code === 0 ? "$(pass) Bootprint" : "$(warning) Bootprint";
      const reveal = settings.get("revealOutput", "always");
      if (code !== 0 && reveal === "onError") output.show(true);
      if (code === 1) {
        await vscode.window.showWarningMessage("Bootprint found a policy violation. See Bootprint Output for details.");
      } else if (code && code !== 0) {
        await vscode.window.showErrorMessage(`Bootprint exited with code ${code}. See Bootprint Output for details.`);
      }
      resolve({ code: code ?? 4 });
    });
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
