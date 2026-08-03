# Understanding findings

Human reports prioritize critical findings, then errors, warnings, and information. JSON and SARIF preserve the same order and stable IDs.

Evidence contains captured metadata only. Remediation commands use placeholders such as `<target-platform>` when Bootprint cannot safely infer an exact command. Commands are preview text and are never passed to a shell.

Suppressed findings remain in machine-readable output with `suppressed: true` and a reason. They do not block CI. Prefer narrow rule suppression over raising the global minimum severity.
