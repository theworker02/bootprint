<p align="center">
  <img src="../../assets/branding/bootprint-logo-128.png" alt="Bootprint logo" width="72">
</p>

# Bootprint plain Ruby example

This package demonstrates Bootprint in a framework-free Ruby application. It declares `DATABASE_URL` as required, captures only the variable's presence, and writes a deterministic schema-v2 lockfile.

```console
bundle install
bundle exec ruby app.rb
bundle exec bootprint snapshot inspect bootprint.lock
bundle exec bootprint doctor
```

No environment-variable value is serialized. Set a placeholder `DATABASE_URL` only if you want to observe the presence metadata change between captures.
