"use strict";

const path = require("node:path");

function commandSpec(settings, platform = process.platform) {
  if (settings.useBundler) {
    if (platform === "win32") {
      return {
        executable: "ruby.exe",
        prefixArguments: ["-S", "bundle", "exec", "bootprint"]
      };
    }

    return {
      executable: "bundle",
      prefixArguments: ["exec", "bootprint"]
    };
  }

  const executable = String(settings.executable || "bootprint").trim();
  if (!executable) {
    throw new Error("bootprint.executable cannot be empty");
  }

  if (platform === "win32" && executable === "bootprint") {
    return { executable: "ruby.exe", prefixArguments: ["-S", "bootprint"] };
  }

  return { executable, prefixArguments: [] };
}

function withPolicy(argumentsList, policyPath, workspaceRoot) {
  const configuredPath = String(policyPath || "").trim();
  if (!configuredPath) return argumentsList.slice();

  const resolvedPath = path.isAbsolute(configuredPath)
    ? configuredPath
    : path.join(workspaceRoot, configuredPath);

  return [...argumentsList, "--policy", resolvedPath];
}

function displayCommand(executable, argumentsList) {
  const quote = (value) => (/\s|"/.test(value) ? JSON.stringify(value) : value);
  return [executable, ...argumentsList].map(quote).join(" ");
}

module.exports = { commandSpec, displayCommand, withPolicy };
