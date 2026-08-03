# Policy configuration

`.bootprint.yml` uses policy schema version 1. Validate it with `bootprint policy validate` and explain effective controls with `bootprint policy explain`.

`mode: permissive` reports information and blocks errors/critical findings by default. `mode: strict` reports warnings and blocks warnings/errors/critical findings. Explicit `minimum_severity` and `fail_on` override these defaults.

Rules accept `enabled: false` and `severity`. `ignore` suppresses known rule IDs. `allow.environment_variables` declares optional names. `expected_platforms` drives lockfile-platform checks. `redaction.patterns` extends built-in secret-name patterns, while `redaction.safe_list` narrowly exempts known non-secret field names. Plugin failures block only in strict mode or when `plugins.strict: true`.

YAML is safe-loaded with aliases and arbitrary Ruby classes disabled. Syntax and semantic errors include absolute file paths and line numbers when identifiable.
