# Architecture

Bootprint is a local-first Ruby gem with no runtime dependencies beyond Ruby standard libraries.

## Data flow

```text
Collectors / plugins
        ↓
recursive sanitization
        ↓
schema-v2 snapshot ──→ deterministic JSON
        ↓
rules + project policy
        ↓
structured findings
        ↓
human / JSON / SARIF / Markdown / CI annotations
```

## Boundaries

- `Bootprint::Snapshot` coordinates collectors, migration, validation, deterministic ordering, and persistence.
- `Bootprint::Schema` owns the current version and migrates schema v1 in memory while preserving unknown top-level fields under `extensions`.
- Collectors return JSON-safe hashes and do not perform network requests.
- `Bootprint::Sanitizer` recursively strips credential-bearing URLs, token-like values, private keys, secret-named fields, and identifying paths.
- `Bootprint::Rules::Rule` defines detection, explanation, metadata, severity, references, source location, and remediation contracts.
- `Bootprint::Diagnosis` evaluates rules and produces a stable report independent of presentation.
- `Bootprint::Policy` validates project control with safe YAML loading and line-aware errors.
- Formatters contain no detection logic.
- Docker and security-audit code are lazy-loaded by their CLI commands.
- Rails hooks load only when `Rails::Railtie` already exists; expensive profiling requires `BOOTPRINT_PROFILE_BOOT=1`.
- The VS Code extension is a workspace-trusted process adapter. It spawns the same Ruby CLI without a shell and contains no duplicate diagnosis logic.

## Plugin contract

Plugin API version `1` accepts a collector class responding to `.capture` or `#capture`, and a rules module responding to `.install` or `.register`. Collector output crosses the same recursive-redaction boundary as core data. Exceptions are converted to snapshot warnings unless strict mode is active.

Plugins cannot inject executable content into snapshots. Registering a plugin is equivalent to requiring trusted Ruby code and therefore remains an application-level trust decision.

## Performance model

The standard capture path uses in-process APIs, file metadata, and `PATH` presence checks. It performs no package-manager calls, remote resolution, or Docker inspection. Comparison is an in-memory traversal. Optional Rails and Docker work stays out of ordinary CLI startup.

## Exit-code ownership

CLI parsing/policy errors use `2`, snapshot/schema errors use `3`, and subsystem/internal failures use `4`. Diagnosis reports determine whether `1` applies from policy `fail_on`; presentation formats do not affect enforcement.
