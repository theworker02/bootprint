# Privacy and redaction

Bootprint uses data minimization first: it does not collect environment-variable values, Rails credentials, full URLs, cookies, sessions, request data, or arbitrary files.

Recursive defense-in-depth redaction handles secret field names, authorization fields, private-key markers, JWT-like strings, high-entropy token-like strings, database/URL credentials, application roots, and user-home paths. Checksum fields are explicitly safe-listed. Strict privacy anonymizes hostname-like values.

Project redaction patterns add organization-specific secret vocabulary. A narrow `redaction.safe_list` can exempt a known non-secret field name; values still pass value-based sanitization. Use `bootprint security audit` to inspect a stored snapshot.
