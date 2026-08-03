# Five-minute quick start

1. Run `bundle exec bootprint capture local` on the working environment.
2. Run `bundle exec bootprint capture production` in the failing environment, or copy the local capture into CI and run `bootprint diagnose --against bootprint.lock` there.
3. Run `bundle exec bootprint diagnose local production`.
4. Review each finding's evidence and suggested command. Bootprint never executes remediation.
5. Copy `.bootprint.yml.example` to `.bootprint.yml`, declare intentional differences, and use `bootprint ci verify`.

Named captures resolve from `.bootprint/NAME.json`, so `local` and `production` can be used instead of full paths.
