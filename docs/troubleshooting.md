# Troubleshooting

- **Docker unavailable:** verify `docker version` succeeds and that the requested image exists locally. Bootprint does not pull it.
- **Initializer list empty:** load Bootprint before Rails initializes and set `BOOTPRINT_INSPECT=1` or `BOOTPRINT_PROFILE_BOOT=1`.
- **Missing environment-variable finding absent:** declare the name with `--required-env`, application configuration, or policy context. Bootprint cannot infer an absent arbitrary name.
- **Unexpected lockfile platform error:** declare actual deployment targets under `expected_platforms` and run `bundle lock --add-platform` deliberately.
- **Policy error:** run `bootprint policy validate`; the error includes the policy path and best-known line.
- **Internal details needed:** set `BOOTPRINT_DEBUG=1` for a stack trace. Review output before sharing because diagnostics may contain local metadata.
