# Docker support

`bootprint docker capture IMAGE` and `bootprint docker diagnose IMAGE --against SNAPSHOT` inspect an image already present locally. Bootprint never pulls an absent image.

The temporary container uses `--rm`, `--read-only`, `--network none`, and a fixed Ruby inspection script. No port is required. The container reports Ruby/gem/platform data, native libraries, installed dpkg/apk package names when available, working-directory permissions, and image entrypoint/command metadata.

The image must contain a working `ruby` executable. Docker errors are returned as exit code 4 with sanitized stderr. Bootprint never lists or inspects unrelated running containers.
