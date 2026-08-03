# Rails integration

Load Bootprint during Rails boot to register `bootprint:capture` and `bootprint:doctor` tasks. Set `BOOTPRINT_INSPECT=1` to observe configuration initializer order without full profiling.

```console
BOOTPRINT_INSPECT=1 bin/rails bootprint:capture
BOOTPRINT_OUTPUT=.bootprint/staging.json bin/rails bootprint:capture
bin/rails bootprint:doctor
```

Set `BOOTPRINT_PROFILE_BOOT=1` for initializer duration, start/completion order, exception metadata, newly loaded constant names, and heuristic network-call observation. The heuristic is intentionally conservative and can report false positives; it does not intercept or block calls.

Bootprint captures adapter names and boolean/presence metadata. It never serializes credentials, database passwords, URLs, cookies, sessions, message contents, or application user data.
