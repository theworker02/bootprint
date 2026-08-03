# Security Policy

## Supported versions

| Version | Security fixes |
|---|---|
| 0.2.x | Supported |
| 0.1.x | Upgrade to 0.2.x |

Until 1.0, security fixes are released on the latest minor line. Older snapshots remain readable when the documented in-memory migration path supports them.

## Data model

Bootprint never reads or stores environment-variable values. It records only selected names with boolean presence. It avoids dumping Rails credentials, database configuration values, authorization headers, command output, complete application files, or arbitrary process memory. Known application-root and home-directory prefixes are replaced with `<APP_ROOT>` and `<HOME>`.

Recursive sanitization detects secret-like field names, credential-bearing URLs, private keys, JWT-like strings, authorization fields, and high-entropy token-like values. Digest and checksum fields are safely distinguished from secrets. Strict privacy mode additionally anonymizes hostname-like strings.

Snapshots can still reveal operational metadata, including:

- gem and native-library versions
- platform and operating-system details
- selected environment-variable names
- Rails adapter and load-path information

Treat `bootprint.lock` as ordinary internal project metadata and review it before making it public. Use `ignored_environment_names` for a name that should never appear:

```ruby
Bootprint.configure do |config|
  config.ignored_environment_names << "INTERNAL_CUSTOMER_CODENAME"
end
```

## Trust boundaries

- Snapshot files are parsed strictly as JSON and never evaluated.
- Policy files use safe YAML loading with aliases and arbitrary classes disabled.
- Rule plugins are executable Ruby code. Install and register them only from trusted gems.
- Bootprint does not upload snapshots, enable telemetry, open ports, or execute Docker commands.
- Capability detection examines executable file presence on `PATH`; it does not run those executables.

Docker commands are the explicit exception to the last point: they invoke only Docker, verify that the requested image exists locally, and create a fixed-script `--rm --read-only --network none` temporary container. Bootprint never inspects unrelated running containers.

Run `bootprint security audit bootprint.lock` before sharing a snapshot outside your organization.

## Reporting vulnerabilities

Please use [GitHub private vulnerability reporting](https://github.com/theworker02/bootprint/security/advisories/new) or email `security@magnexis.com`. Do not open a public issue or include real credentials or production snapshots. Include the affected Bootprint version, operating system, Ruby engine, sanitized reproduction, and expected impact. Expect acknowledgement within seven days.
