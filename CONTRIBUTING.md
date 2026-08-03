# Contributing

Thank you for improving Bootprint. Open an issue before large architectural work. Keep the project focused on Ruby runtime reproducibility and local-first diagnosis. By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Setup

The repository pins the maintainer runtime in `.ruby-version`; the gem itself supports Ruby 3.1 and newer.

```console
bundle install
bundle exec rake check
```

Use a focused branch created from `main`. Keep commits reviewable and do not mix generated snapshots, local package artifacts, or unrelated formatting with a behavior change.

## Pull requests

Describe the failing environment scenario, the compatibility decision being encoded, and the sanitized evidence used to verify it. Complete the pull-request checklist and call out platform behavior you could not test.

Changes to rules require success, no-match, suppression, evidence, and remediation tests. Schema changes require migration and future-schema tests. Security changes require both redaction and false-positive coverage. Docker tests must never inspect unrelated containers or require network access.

Do not include real production snapshots, credentials, customer names, or proprietary paths in fixtures. Use the existing synthetic platform fixtures.

Pull requests should update documentation and `CHANGELOG.md`, remain compatible with Ruby 3.1+, and avoid new runtime dependencies unless clearly justified.

## Releases

Maintainers should follow [RELEASE.md](RELEASE.md). Pull requests must not publish gems, create tags, or add long-lived package credentials.
