# Changelog

All notable changes to Bootprint are documented here. The project follows Semantic Versioning before and after 1.0 where practical.

## Unreleased

## 0.5.0 - 2026-08-14

### Added

- Capture timezone, default encodings, and locale metadata on the operating-system fingerprint.
- Built-in rules `timezone-drift`, `encoding-drift`, and `locale-drift` for those fields.

## 0.4.0 - 2026-08-11

### Added

- `Bootprint::Advisories` for matching snapshot gem versions against offline JSON advisory bundles.
- `Bootprint.advisories` and `Bootprint.advise` convenience APIs.
- `bootprint advisories SNAPSHOT` CLI command with `--bundle` and `--format human|json` options.
- Sample empty advisory bundle schema at `data/advisories/schema/empty.json`.

## 0.3.0 - 2026-08-04

### Added

- `Bootprint::Matrix` for comparing two or more named snapshots at once.
- Majority-based consensus values for multi-environment drift analysis.
- Deterministic outlier identification and per-environment outlier counts.
- Missing-value reporting for incomplete staging, CI, container, or production fingerprints.
- `Bootprint.matrix` as the public convenience API.
- Stable matrix JSON through `Matrix#to_h`.

### Compatibility

- Existing capture, diff, diagnosis, policy, report, CLI, Rails, and plugin APIs are unchanged.
- Generated timestamps, environment labels, and capture metadata remain excluded from semantic comparisons.

## 0.2.0 - 2026-08-02

### Added

- Stable snapshot schema v2 with deterministic output, v1 migration, inspection, validation, and safe migration commands.
- Formal rule DSL and 39 built-in compatibility rules with cause, impact, evidence, severity, and remediation.
- `diagnose`, `fix --dry-run`, policy, snapshot, Docker, CI, and security-audit commands.
- Human, JSON report-schema v1, SARIF 2.1, and Markdown output.
- Strict/permissive `.bootprint.yml` policies with rule controls, expected platforms, optional variables, and redaction patterns.
- Expanded Rails configuration inspection, opt-in initializer profiling, and Rails tasks.
- Read-only, network-disabled Docker image capture.
- Plugin API v1 with isolated failures.
- Recursive privacy hardening and strict privacy mode.
- Cross-platform fixtures, subprocess integration tests, CI matrix, examples, and public contributor documentation.
- Original Bootprint brand mark, packaged logo assets, README badges, and expanded product and workflow documentation.
- Release package validation, installed-gem smoke tests, GitHub security automation, and OIDC-based RubyGems trusted publishing.
- Focused four-job compatibility CI, grouped monthly dependency updates, and a weekly/manual security audit to reduce workflow noise.
- Presence-only handling for secret-named environment variables across the sanitizer and snapshot schema boundary.

## 0.1.0 - 2026-08-02

- Added sanitized runtime capture, comparison, initial diagnostics, Rails collection, CI verification, reports, allowed differences, and the first rule DSL.
