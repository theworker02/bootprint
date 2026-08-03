"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");
const { commandSpec, displayCommand, withPolicy } = require("../src/command");

test("uses Bundler without invoking a shell", () => {
  assert.deepEqual(commandSpec({ useBundler: true }, "linux"), {
    executable: "bundle",
    prefixArguments: ["exec", "bootprint"]
  });
  assert.deepEqual(commandSpec({ useBundler: true }, "win32"), {
    executable: "ruby.exe",
    prefixArguments: ["-S", "bundle", "exec", "bootprint"]
  });
});

test("supports a directly configured executable", () => {
  assert.deepEqual(commandSpec({ useBundler: false, executable: "/opt/bootprint/bin/bootprint" }, "linux"), {
    executable: "/opt/bootprint/bin/bootprint",
    prefixArguments: []
  });
  assert.deepEqual(commandSpec({ useBundler: false, executable: "bootprint" }, "win32"), {
    executable: "ruby.exe",
    prefixArguments: ["-S", "bootprint"]
  });
  assert.throws(() => commandSpec({ useBundler: false, executable: "  " }), /cannot be empty/);
});

test("adds an absolute policy path without mutating arguments", () => {
  const original = ["doctor"];
  const actual = withPolicy(original, "config/bootprint.yml", path.join("workspace", "app"));
  assert.deepEqual(actual, ["doctor", "--policy", path.join("workspace", "app", "config", "bootprint.yml")]);
  assert.deepEqual(original, ["doctor"]);
});

test("quotes command display values containing spaces", () => {
  assert.equal(displayCommand("bundle", ["exec", "bootprint", "--against", "a path/file.json"]),
    'bundle exec bootprint --against "a path/file.json"');
});
