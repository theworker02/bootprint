# Comparing environments and understanding findings

Use `bootprint diff SOURCE TARGET` for a complete raw comparison. Use `bootprint diagnose SOURCE TARGET` for compatibility intelligence.

Findings have four severities:

- `info`: useful context with negligible direct risk
- `warning`: likely drift that deserves review
- `error`: behavior or installation is likely to fail
- `critical`: boot, security, or binary compatibility is at immediate risk

Each finding contains a stable rule ID, category, cause, impact, evidence, remediation, optional commands/files, references, and suppression status. `--minimum-severity` controls presentation; policy `fail_on` controls exit code.

## macOS Rails to Linux container

```console
bootprint capture macos-development
bootprint docker capture registry.example/myapp:latest --output .bootprint/linux-production.json
bootprint diagnose macos-development linux-production --only runtime,dependencies,native,configuration
```

A native `nokogiri` Darwin variant produces a critical platform finding with `bundle lock --add-platform x86_64-linux`. A local-only `REDIS_URL` produces an error without revealing its value. Case sensitivity appears as a warning.
