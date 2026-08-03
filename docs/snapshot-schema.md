# Snapshot schema v2

Every snapshot contains `schema_version`, `generated_at`, `bootprint_version`, `environment`, and optional `capture`/`extensions` metadata. `environment` contains `name`, `runtime`, `dependencies`, `native_libraries`, `configuration`, `filesystem`, and `operating_system` objects.

Keys are recursively sorted. Scalar arrays are sorted; ordered object arrays such as Rails initializers retain capture order. `generated_at`, Bootprint version, capture duration, warnings, and environment labels do not participate in raw environment equality.

Schema v1 is migrated in memory. Unknown v1 top-level fields move to `extensions`. Future schemas fail with an instruction to upgrade. `snapshot migrate` always writes a new file unless an explicit output path is selected; it does not overwrite the source by default.

Diagnosis JSON uses its own report schema version 1 so snapshot and report evolution remain independent.
