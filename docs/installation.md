# Installation

Bootprint supports MRI Ruby 3.1+ and is designed to degrade safely on JRuby. Install globally with `gem install bootprint`, or add `gem "bootprint", require: false` to development and test groups and run `bundle install`.

The core gem has no runtime dependencies. Docker support requires a local Docker CLI and running daemon. Rails inspection requires Rails to load Bootprint during application boot.

Verify the installation with `bootprint version` and `bootprint doctor`.
