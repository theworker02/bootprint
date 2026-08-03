<p align="center">
  <img src="../../assets/branding/bootprint-logo-128.png" alt="Bootprint logo" width="72">
</p>

# Bootprint Rails example

This package demonstrates Railtie loading, Rails configuration collection, and initializer presence-only inspection.

```console
bundle install
BOOTPRINT_INSPECT=1 bundle exec rails bootprint:capture
bundle exec rails bootprint:doctor
BOOTPRINT_PROFILE_BOOT=1 bundle exec rails runner "Bootprint.capture.write('bootprint.lock')"
```

It is documentation scaffolding rather than a production Rails application and intentionally includes no database credentials or generated secrets.
