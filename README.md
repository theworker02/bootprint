<p align="center">
  <img src="assets/branding/bootprint-logo-512.png" alt="Bootprint fingerprint and environment-drift logo" width="180">
</p>

<h1 align="center">Bootprint</h1>

<p align="center"><strong>Reproduce the environment, not just the dependencies.</strong></p>

<p align="center">
  <a href="https://github.com/theworker02/bootprint/actions/workflows/test.yml"><img alt="Test status" src="https://github.com/theworker02/bootprint/actions/workflows/test.yml/badge.svg"></a>
  <a href="https://rubygems.org/gems/bootprint"><img alt="Bootprint on RubyGems" src="https://img.shields.io/gem/v/bootprint?logo=rubygems&logoColor=white&color=CC342D"></a>
  <a href="https://open-vsx.org/extension/theworker02/bootprint"><img alt="Bootprint on Open VSX" src="https://img.shields.io/open-vsx/v/theworker02/bootprint?label=Open%20VSX&color=6C4FBB"></a>
  <a href="https://theworker02.github.io/bootprint/"><img alt="Bootprint website" src="https://img.shields.io/badge/website-GitHub%20Pages-3977F6?logo=githubpages&logoColor=white"></a>
  <img alt="Ruby 3.1 or newer" src="https://img.shields.io/badge/Ruby-%E2%89%A5%203.1-CC342D?logo=ruby&logoColor=white">
  <img alt="Snapshot schema version 2" src="https://img.shields.io/badge/snapshot_schema-v2-3977F6">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-171A21"></a>
</p>

Bootprint is a local-first Ruby runtime fingerprint and compatibility diagnostic. It captures a sanitized description of an application environment, compares that description with CI, Docker, staging, or production, and turns raw drift into explanations, severity, evidence, remediation, and enforceable policy.

Explore the project at [theworker02.github.io/bootprint](https://theworker02.github.io/bootprint/).

Install the official [`bootprint` gem from RubyGems.org](https://rubygems.org/gems/bootprint):

```console
gem install bootprint
bootprint capture local
bootprint docker capture myapp:latest
bootprint diagnose local myapp-latest
```

The official editor extension is available from [Open VSX as `theworker02.bootprint`](https://open-vsx.org/extension/theworker02/bootprint).

Bootprint 0.2 combines a dependency compatibility analyzer, Rails boot inspector, environment-drift detector, and CI policy engine. Ordinary capture performs no network requests, suggested commands never execute automatically, and environment-variable values are never recorded.

## Contents

- [Why Bootprint](#why-bootprint)
- [What it inspects](#what-it-inspects)
- [Five-minute start](#five-minute-start)
- [From capture to diagnosis](#from-capture-to-diagnosis)
- [Command reference](#command-reference)
- [Policy enforcement](#policy-enforcement)
- [Rails inspection](#rails-inspection)
- [Docker comparison](#docker-comparison)
- [CI integration](#ci-integration)
- [Reports and remediation](#reports-and-remediation)
- [Rules and plugins](#rules-and-plugins)
- [Privacy and security](#privacy-and-security)
- [Platform support and performance](#platform-support-and-performance)
- [VS Code extension](#vs-code-extension)
- [Documentation](#documentation)
- [Development](#development)

## Why Bootprint

`Gemfile.lock` captures dependency resolution, but not the complete runtime contract. Ruby engine and patch level, native clients, libc, CPU architecture, Rails adapters, required configuration, filesystem behavior, and initializer ordering can all change application behavior.

Bootprint records those facts as deterministic schema-v2 JSON and evaluates them with 42 independently testable built-in rules. A finding answers four questions that a plain diff cannot:

1. What changed?
2. How dangerous is it?
3. What is the likely impact?
4. What should the developer do next?

```text
CRITICAL   Native extension platform mismatch
           nokogiri targets arm64-darwin but production uses x86_64-linux.

           Recommended fix:
           $ bundle lock --add-platform x86_64-linux
           $ bundle install

ERROR      Required environment variable is missing
           REDIS_URL is available locally but absent in production.
```

### At a glance

| Capability | Bootprint 0.2 |
|---|---|
| Diagnostic knowledge | 42 built-in rules across runtime, dependencies, native libraries, configuration, filesystem, locale, and Rails boot |
| Severity model | `info`, `warning`, `error`, `critical` |
| Report formats | Human terminal output, JSON, SARIF 2.1, Markdown |
| Snapshot contract | Deterministic schema v2 with in-memory v1 migration |
| Policy | Ignore, enable, disable, override severity, declare optional variables, require platforms |
| Integrations | Rails, Docker, GitHub Actions, GitLab CI, CircleCI, generic POSIX CI |
| Runtime dependencies | None |
| Data flow | Local only; no upload service or telemetry |

## What it inspects

| Area | Captured metadata |
|---|---|
| Ruby runtime | Version, engine, patch level, platform, architecture, build description |
| Dependency system | Bundler and RubyGems versions, lockfile platforms, resolved gems, sources, checksums, native extensions |
| Native libraries | OpenSSL, libyaml, SQLite, PostgreSQL, MySQL, libc, compiler and header availability when detectable |
| Configuration | Environment-variable names and presence, Rails environment, adapters, framework settings |
| Filesystem | Temporary/log path availability, writability, path separators, case sensitivity, symlink behavior |
| Locale | Timezone name and UTC offset, default internal/external encodings, LANG / LC_ALL / charmap |
| Rails boot | Framework configuration, autoload/eager-load paths, initializers, and opt-in initializer timings |
| Docker | Image runtime, platforms, installed package metadata when available, workdir, entrypoint, command, permissions |

Bootprint deliberately does **not** collect credential values, database passwords, API tokens, cookies, session contents, full connection URLs, user data, or application source. Strict privacy mode additionally omits or normalizes hostnames, usernames, home paths, and process identifiers.

## Five-minute start

Add Bootprint to a project:

```ruby
group :development, :test do
  gem "bootprint", require: false
end
```

Install and capture a named local baseline:

```console
bundle install
bundle exec bootprint capture local
```

Capture another environment and diagnose the difference:

```console
bundle exec bootprint capture production
bundle exec bootprint diagnose local production
```

Named captures live at `.bootprint/NAME.json`. An unnamed capture writes `bootprint.lock`:

```console
bundle exec bootprint capture
bundle exec bootprint verify --against bootprint.lock
```

Use strict privacy when a snapshot may be attached to an issue or shared outside the team:

```console
bundle exec bootprint capture support-case --privacy strict
bundle exec bootprint security audit .bootprint/support-case.json
```

## From capture to diagnosis

```text
Ruby process / Rails app / Docker image
                  |
                  v
        sanitized collectors
                  |
                  v
      deterministic schema-v2 snapshot
                  |
            source + target
                  |
                  v
       rules + .bootprint.yml policy
                  |
                  v
 human | JSON | SARIF | Markdown + stable exit code
```

For example, compare a local macOS Rails environment with a Linux production image:

```console
# macOS development machine
bundle exec bootprint capture macos-development

# Local Docker image; no port or running container is required
bundle exec bootprint docker capture ghcr.io/example/storefront:latest

# Explain only warning-or-higher runtime and dependency findings
bundle exec bootprint diagnose macos-development storefront-latest \
  --only runtime,dependencies \
  --minimum-severity warning
```

Raw `diff` remains available when every changed value matters. `diagnose` is the normal workflow because it applies compatibility knowledge and policy.

## Command reference

| Command | Purpose |
|---|---|
| `bootprint capture [NAME]` | Capture a deterministic, sanitized schema-v2 snapshot |
| `bootprint diff SOURCE TARGET` | Show every raw environment difference |
| `bootprint diagnose SOURCE TARGET` | Explain compatibility findings and remediation |
| `bootprint diagnose --against PATH` | Compare the current process with a reference snapshot |
| `bootprint doctor` | Diagnose the health of the current environment |
| `bootprint verify --against PATH` | Enforce policy and return CI-safe exit codes |
| `bootprint fix --dry-run` | Preview remediation without changing files or running commands |
| `bootprint docker capture IMAGE` | Inspect a local image in an isolated temporary container |
| `bootprint docker compare IMAGE` | Show raw drift between the current environment and an image |
| `bootprint docker diagnose IMAGE` | Diagnose current-environment versus image compatibility |
| `bootprint ci verify` | Detect CI, emit native annotations, and enforce policy |
| `bootprint snapshot inspect PATH` | Inspect snapshot metadata safely |
| `bootprint snapshot validate PATH` | Validate schema and snapshot structure |
| `bootprint snapshot migrate PATH` | Migrate a legacy snapshot into a new file |
| `bootprint policy validate` | Validate policy with path and line-aware errors |
| `bootprint policy explain` | Display the effective merged policy |
| `bootprint security audit PATH` | Check an existing snapshot for likely sensitive values |

Diagnosis supports `--format human|json|sarif|markdown`, `--only CATEGORY,...`, and `--minimum-severity LEVEL`. Color is disabled when output is redirected or `NO_COLOR` is set.

## Policy enforcement

Copy `.bootprint.yml.example` to `.bootprint.yml` and tailor it:

```yaml
version: 1
mode: permissive
minimum_severity: warning
fail_on: [error, critical]

expected_platforms: [x86_64-linux]
ignore: [ruby-patch-level-drift]

allow:
  environment_variables: [OPTIONAL_ANALYTICS_KEY]

rules:
  missing-environment-variable:
    severity: critical

redaction:
  patterns: [TOKEN, SECRET, PASSWORD, PRIVATE_KEY]
```

Policies can disable rules, override severity, acknowledge known differences, declare optional environment variables, define deployment platforms and redaction patterns, and select strict or permissive behavior. Validate before CI enforcement:

```console
bundle exec bootprint policy validate
bundle exec bootprint policy explain
bundle exec bootprint verify --against bootprint.lock
```

Exit codes are stable:

| Code | Meaning |
|---:|---|
| 0 | No blocking findings |
| 1 | Policy violation |
| 2 | Invalid command or policy |
| 3 | Invalid or unsupported snapshot |
| 4 | Docker, plugin, filesystem, or internal failure |

## Rails inspection

Bootprint lazily loads Rails integration only after Rails is present. Normal application startup is not profiled unless inspection is explicitly enabled.

```console
BOOTPRINT_INSPECT=1 bin/rails bootprint:capture
bin/rails bootprint:doctor
BOOTPRINT_PROFILE_BOOT=1 bundle exec rails runner "Bootprint.capture.write('bootprint.lock')"
```

Rails capture includes the version and environment, framework defaults, eager loading, cache classes, paths, database/queue/cache/session adapters, Active Storage, Action Cable, mail delivery, time zone, logging, public-file serving, assets, and initializer order.

Opt-in profiling records initializer start and completion order, duration, exception metadata, newly loaded constant names, and a conservative network-operation heuristic. It never captures credentials, connection URLs, cookie contents, session contents, or user data.

## Docker comparison

Docker inspection requires a local image containing Ruby. Bootprint checks that the image already exists, then runs a read-only, network-disabled `--rm` container with a fixed inspection script.

```console
bootprint docker capture myapp:latest
bootprint docker diagnose myapp:latest --against local
```

Bootprint does not pull images, expose ports, persist temporary containers, inspect unrelated running containers, or upload captured data. If Docker is missing or unavailable, the CLI reports that condition with exit code 4.

## CI integration

Commit a trusted `bootprint.lock` and enforce it in pull requests:

```yaml
name: Bootprint

on:
  pull_request:
  push:

jobs:
  environment-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec bootprint ci verify --against bootprint.lock
```

`bootprint ci verify` detects GitHub Actions, GitLab CI, CircleCI, and generic POSIX CI environments. GitHub output includes workflow annotations and a Markdown job summary; SARIF output can be consumed by GitHub code scanning without inventing file locations.

## Reports and remediation

Machine-readable JSON contains report schema version, source and target metadata, findings, evidence, remediation, suppression state, and execution metadata:

```console
bootprint diagnose local production --format json > bootprint-report.json
bootprint diagnose local production --format sarif > bootprint.sarif
bootprint diagnose local production --format markdown > bootprint-report.md
```

Every actionable finding can include safe, structured repair guidance:

```json
{
  "rule_id": "missing-lockfile-platform",
  "severity": "error",
  "evidence": {
    "current_platforms": ["arm64-darwin"],
    "required_platforms": ["x86_64-linux"]
  },
  "remediation": {
    "summary": "Add the deployment platform to the lockfile and rebuild the bundle.",
    "commands": [
      "bundle lock --add-platform <required-platform>",
      "bundle install"
    ],
    "files": ["Gemfile.lock"]
  }
}
```

`bootprint fix --dry-run` renders those changes as a preview. Diagnosis and preview never execute remediation commands or modify application files.

## Rules and plugins

Rules use a structured DSL and load without Rails:

```ruby
Bootprint::Rules.define "redis-client-drift" do
  name "Redis client mismatch"
  category :dependencies
  severity :warning

  detect do |source, target|
    source.dig("plugins", "redis") != target.dig("plugins", "redis")
  end

  explain do |_source, _target, evidence|
    { summary: "Redis clients differ.", evidence: evidence }
  end

  remediate "Pin the same redis-client release in Gemfile.lock.",
            files: ["Gemfile.lock"]
end
```

Third-party gems can package collectors and rules behind plugin API version 1:

```ruby
Bootprint::Plugin.api_version "1"

Bootprint::Plugins.register "sidekiq" do
  collector SidekiqBootprint::Collector
  rules SidekiqBootprint::Rules
end
```

A broken plugin becomes a warning and does not prevent core capture unless strict policy mode is enabled. See [Writing custom rules](docs/custom-rules.md) and [Creating plugins](docs/plugins.md) for the compatibility contract.

## Privacy and security

Environment inspection is sensitive, so Bootprint applies defensive handling at collection and serialization boundaries:

- Environment variables are represented by name and presence only.
- Recursive redaction detects secret-like names, credentials in URLs, authorization headers, private keys, JWT-like tokens, database connection strings, and high-entropy values.
- Home paths are normalized; strict mode removes further host and process identity.
- Unknown snapshot fields are preserved where practical during migration, then audited like known fields.
- Standard capture performs no network requests and enables no telemetry.
- Suggested shell commands remain inert data.

Before sharing any snapshot, run:

```console
bootprint security audit bootprint.lock
```

Security issues should follow the private reporting process in [SECURITY.md](SECURITY.md), not a public issue containing a snapshot.

## Platform support and performance

The focused automated matrix covers the oldest supported MRI release on Linux and Ruby 3.4 on Linux, macOS, and Windows. Fixture coverage includes macOS development, Linux CI, Docker production, Windows development, ARM64 development, x86-64 deployment, Rails, and plain Ruby projects.

Bootprint is designed around these practical limits:

| Operation | Target |
|---|---:|
| Core CLI startup | Under 250 ms where practical |
| Standard Ruby snapshot | Under 1 second |
| Rails inspection | Under 3 seconds, excluding application boot |
| Ordinary snapshot comparison | Under 500 ms |

Rails, Docker, SARIF, and plugin code are lazy-loaded so basic CLI use does not pay for integrations it does not invoke. Performance varies with Ruby, filesystem, dependency count, and host load.

## VS Code extension

Bootprint includes an Open VSX-ready editor extension in [`editors/vscode`](editors/vscode), available from the official [`theworker02.bootprint` Open VSX listing](https://open-vsx.org/extension/theworker02/bootprint). It provides capture, diagnose, doctor, and verify commands, streams CLI output inside the editor, and adds snapshot diagnosis to the Explorer context menu.

Install it from an Open VSX-compatible editor or with VSCodium:

```console
codium --install-extension theworker02.bootprint
```

The extension uses the workspace bundle by default:

```ruby
gem "bootprint", "~> 0.2"
```

Build and install the versioned VSIX locally:

```console
cd editors/vscode
npm install
npm run check
npm run package:vsix
code --install-extension ../../pkg/bootprint-vscode-0.2.1.vsix --force
```

See the [editor extension guide](editors/vscode/README.md) for commands, configuration, trust behavior, Open VSX setup, and direct-executable setup.

## Documentation

- [Installation](docs/installation.md)
- [Five-minute quick start](docs/quick-start.md)
- [Capturing environments](docs/capturing.md)
- [Comparing environments](docs/comparing.md)
- [Understanding findings](docs/findings.md)
- [Policy configuration](docs/policy.md)
- [Rails integration](docs/rails.md)
- [Docker support](docs/docker.md)
- [CI integration](docs/ci.md)
- [Writing custom rules](docs/custom-rules.md)
- [Creating plugins](docs/plugins.md)
- [Privacy and redaction](docs/privacy.md)
- [Snapshot schema](docs/snapshot-schema.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Maintainer setup](docs/maintainer-setup.md)
- [VS Code extension](editors/vscode/README.md)
- [Open VSX publishing](docs/open-vsx.md)

## Development

```console
bundle install
bundle exec rake test
bundle exec rubocop lib test exe Rakefile bootprint.gemspec
gem build bootprint.gemspec
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, [ARCHITECTURE.md](ARCHITECTURE.md) for system boundaries, and [RELEASE.md](RELEASE.md) for packaging and signed-release instructions.

## Status and limitations

Bootprint 0.2 is local-first and pre-1.0. It diagnoses captured facts; it does not guarantee perfect binary compatibility, query remote gem indexes during capture, execute suggested repairs, or provide malware isolation. Yanked-gem detection uses metadata supplied by snapshots or trusted plugins because standard capture deliberately avoids network access.

Bootprint is released under the [MIT License](LICENSE).
