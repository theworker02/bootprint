# Multi-environment matrix

Bootprint 0.3.0 can compare a fleet of named snapshots instead of only a local/target pair.

```ruby
matrix = Bootprint.matrix(
  local: Bootprint::Snapshot.load("tmp/local.json"),
  ci: Bootprint::Snapshot.load("tmp/ci.json"),
  staging: Bootprint::Snapshot.load("tmp/staging.json"),
  production: Bootprint::Snapshot.load("tmp/production.json")
)

matrix.entries.each do |entry|
  puts "#{entry.path}: consensus=#{entry.consensus.inspect} outliers=#{entry.outliers.join(',')}"
end
```

A matrix entry contains:

- the deterministic dotted path;
- values by environment;
- environments where the path is missing;
- a consensus value when a strict majority agrees;
- the environments outside that consensus.

`outlier_counts` ranks environments by the number of divergent paths. When no strict majority exists, every environment is reported as an outlier for that path instead of guessing which value is correct.

Bootprint excludes the same non-semantic timestamps, labels, and capture metadata used by pairwise diffing.
