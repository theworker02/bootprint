# CI integration

Use the same committed `bootprint.lock` in generic POSIX CI, GitLab CI, CircleCI, or GitHub Actions:

```yaml
name: Bootprint
on: [pull_request, push]
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

GitHub Actions receives workflow annotations and Markdown appended to `GITHUB_STEP_SUMMARY`. SARIF output is compatible with GitHub code scanning when uploaded by the workflow. Bootprint does not upload reports itself.

GitLab, CircleCI, and generic CI receive stable console output and exit codes. CI provider detection uses standard environment-variable presence, not secret values.
