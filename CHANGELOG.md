# Changelog

All notable changes to Bootprint are documented here. The project follows Semantic Versioning before and after 1.0 where practical.

## Unreleased

### Added

- A versioned Open VSX extension package (`theworker02.bootprint`) with capture, diagnose, doctor, verify, installation-check, streamed-output, workspace-trust, and configurable Bundler support.
- A manual-only, protected Open VSX packaging and publishing workflow using the pinned `ovsx` CLI.
- A responsive, dependency-free GitHub Pages product site with the Bootprint brand, live distribution links, accessible interactions, and a dedicated social preview.

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
