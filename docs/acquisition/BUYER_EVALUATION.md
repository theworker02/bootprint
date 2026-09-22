# Buyer evaluation â€” macOS development machine

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

```
```console
gem install bootprint
bootprint capture local
bootprint docker capture myapp:latest
bootprint diagnose local myapp-latest
```
```text
CRITICAL   Native extension platform mismatch
           nokogiri targets arm64-darwin but production uses x86_64-linux.

           Recommended fix:
           $ bundle lock --add-platform x86_64-linux
           $ bundle install

ERROR      Required environment variable is missing
           REDIS_URL is available locally but absent in production.
```
```ruby
group :development, :test do
  gem "bootprint", require: false
end
```
```console
bundle install
bundle exec bootprint capture local
```
```console
bundle exec bootprint capture production
bundle exec bootprint diagnose local production
```
```console
bundle exec bootprint capture
bundle exec bootprint verify --against bootprint.lock
```
```console
bundle exec bootprint capture support-case --privacy strict
bundle exec bootprint security audit .bootprint/support-case.json
```
```text
Ruby process / Rails app / Docker image
```

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*
