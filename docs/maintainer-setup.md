# GitHub and RubyGems maintainer setup

This checklist covers settings that cannot be represented completely by committed files. Apply it after creating `theworker02/bootprint` and before publishing the first gem.

## Repository profile

- Description: `Diagnose why Ruby environments work locally but fail in CI, Docker, staging, or production.`
- Website: `https://theworker02.github.io/bootprint/`
- Topics: `ruby`, `rails`, `bundler`, `rubygems`, `docker`, `ci`, `diagnostics`, `reproducibility`, `developer-tools`
- Default branch: `main`
- Social preview: `site/assets/bootprint-social.png`
- Enable Issues and Discussions; disable the wiki unless maintainers intend to support it.

## Ruleset for `main`

- Require pull requests and at least one approving review.
- Dismiss stale approvals when new commits are pushed.
- Require conversation resolution.
- Require the four focused CI compatibility checks.
- Require branches to be up to date before merging.
- Block force pushes and branch deletion.
- Restrict bypass permission to release maintainers.
- Add a tag ruleset protecting `v*` from deletion or update.

CodeQL runs weekly or on explicit maintainer request rather than adding another check to every pull request.

## GitHub Pages

In **Settings → Pages**, set the publishing source to **GitHub Actions**. The focused `pages.yml` workflow deploys only the dependency-free files under `site/` when that directory changes or when a maintainer runs it manually.

- Expected URL: `https://theworker02.github.io/bootprint/`
- Deployment environment: `github-pages`
- Allow deployments only from `main`.
- Set the repository website field to the Pages URL after the first successful deployment.
- Do not add a custom domain or `CNAME` until its DNS ownership is verified.

## Actions and security

- Allow GitHub-authored actions plus `ruby/setup-ruby` and `rubygems/release-gem`.
- Keep the default workflow token read-only; grant write permissions only inside the release job.
- Enable the dependency graph, Dependabot alerts, Dependabot security updates, secret scanning, and push protection.
- Review and merge Dependabot updates rather than enabling unattended auto-merge.
- Enable private vulnerability reporting and repository security advisories.
- Retain Actions logs long enough to investigate releases, without treating logs as a secret store.

## Release environment

Create an environment named `release`:

- Require approval from a release maintainer.
- Allow deployment only from tags matching `v*`.
- Do not add `RUBYGEMS_API_KEY`; trusted publishing uses OIDC.
- Do not expose unrelated organization secrets to the workflow.

Then create the RubyGems trusted publisher described in [RELEASE.md](../RELEASE.md). The repository owner, repository name, workflow filename, and environment must match exactly.

## First-publication checklist

- Confirm `gem search --remote --exact bootprint` still returns no existing gem.
- Confirm the repository URLs and `hello@magnexis.com`, `security@magnexis.com`, and `conduct@magnexis.com` mailboxes are controlled and monitored.
- Confirm the name and copyright holder in `LICENSE` are intentional.
- Run `bundle exec rake release_check` from a clean checkout.
- Review the packaged file list and installed CLI behavior.
- Push `main`, wait for every required check, then create the signed `v0.2.0` tag.
