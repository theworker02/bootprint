# Creating plugins

Plugin gems should use names such as `bootprint-sidekiq` or `bootprint-redis`, call `Bootprint::Plugin.api_version "1"`, and register a stable plugin name.

Collectors return JSON-safe data and must not return secrets. Bootprint applies recursive sanitization regardless. Rules modules respond to `.install` or `.register` and use the ordinary rule DSL.

One plugin exception becomes a warning stored in `capture.warnings`; other collectors continue. Strict policy converts plugin failures into capture failures. Plugins are executable Ruby code and must be installed only from trusted sources.
