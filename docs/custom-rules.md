# Writing custom rules

Define rules after requiring `bootprint`. Rules receive source and target schema-v2 `environment` objects; a third argument receives the active policy.

Detection returns `false`/`nil` for no finding, `true` for a finding without custom evidence, or a hash containing evidence. Explanation returns `summary`, `cause`, `impact`, `evidence`, and optional `source_location`. Remediation is always structured and preview-only.

Rule IDs are global and later definitions replace earlier rules with the same ID, allowing an application to intentionally customize built-ins. Prefer namespaced IDs for third-party packages. Test rules against fixture snapshots without requiring Rails.
