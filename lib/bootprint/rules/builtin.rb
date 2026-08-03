# frozen_string_literal: true

require "rubygems"

module Bootprint
  module Rules
    module Builtin
      module_function

      def install
        runtime_rules
        dependency_rules
        native_library_rules
        configuration_rules
        filesystem_rules
        initializer_rules
      end

      def runtime_rules
        rule("ruby-version-drift", "Ruby version mismatch", :runtime, :error,
             cause: "The environments select different Ruby releases.",
             impact: "Language behavior, standard libraries, and native-extension ABIs may differ.",
             fix: "Pin the same Ruby version in local, container, and CI configuration.",
             commands: ["ruby --version"], files: [".ruby-version"], location: ".ruby-version") do |source, target|
          difference(source, target, "runtime.ruby_version")
        end
        rule("ruby-engine-drift", "Ruby engine mismatch", :runtime, :critical,
             impact: "MRI, JRuby, and TruffleRuby have different runtime and extension compatibility.",
             fix: "Use the same Ruby engine in every environment.", files: [".ruby-version"], location: ".ruby-version") do |source, target|
          difference(source, target, "runtime.engine")
        end
        rule("ruby-patch-level-drift", "Ruby patch-level drift", :runtime, :warning,
             impact: "Patch releases can include security, parser, and native-runtime changes.",
             fix: "Update the older environment to the pinned Ruby patch release.", files: [".ruby-version"], location: ".ruby-version") do |source, target|
          difference(source, target, "runtime.patchlevel")
        end
        rule("architecture-mismatch", "CPU architecture mismatch", :runtime, :critical,
             impact: "Compiled gems cannot be reused across incompatible CPU architectures.",
             fix: "Build gems on the deployment architecture or use a matching multi-architecture image.") do |source, target|
          difference(source, target, "runtime.architecture")
        end
        rule("operating-system-mismatch", "Operating-system mismatch", :runtime, :warning,
             impact: "System libraries, path behavior, and available native packages can differ.",
             fix: "Develop in a container or VM matching the deployment operating system.") do |source, target|
          difference(source, target, "operating_system.name")
        end
        rule("unsupported-ruby-version", "Unsupported Ruby version", :runtime, :critical,
             cause: "The target Ruby predates Bootprint's supported runtime floor.",
             impact: "The runtime may lack security fixes and required language APIs.",
             fix: "Upgrade the target to a maintained Ruby release.", references: ["https://www.ruby-lang.org/en/downloads/branches/"]) do |_source, target|
          value = dig(target, "runtime.ruby_version")
          value && Gem::Version.new(value) < Gem::Version.new("3.1.0") && { "target" => value, "minimum" => "3.1.0" }
        rescue ArgumentError
          false
        end
        rule("debug-ruby-build", "Debug Ruby build detected", :runtime, :warning,
             impact: "Debug runtimes can be substantially slower and differ in assertion behavior.",
             fix: "Use a standard release build for production.") do |_source, target|
          dig(target, "runtime.debug_build") == true && { "description" => dig(target, "runtime.description") }
        end
      end

      def dependency_rules
        rule("bundler-version-drift", "Bundler version mismatch", :dependencies, :warning,
             impact: "Dependency resolution and lockfile serialization may change.",
             fix: "Install and invoke the Bundler version recorded in Gemfile.lock.",
             commands: ["gem install bundler -v <locked-version>", "bundle _<locked-version>_ install"], files: ["Gemfile.lock"], location: "Gemfile.lock") do |source, target|
          difference(source, target, "dependencies.toolchain.bundler_version")
        end
        rule("rubygems-version-drift", "RubyGems version mismatch", :dependencies, :warning,
             impact: "Platform selection and gem installation behavior may differ.",
             fix: "Align RubyGems versions or use the Ruby distribution's supported version.") do |source, target|
          difference(source, target, "dependencies.toolchain.rubygems_version")
        end
        rule("lockfile-platform-drift", "Lockfile platform sets differ", :dependencies, :error,
             impact: "Bundler may resolve different gem variants in deployment.",
             fix: "Add every deployment platform and regenerate the lockfile.",
             commands: ["bundle lock --add-platform <platform>", "bundle install"], files: ["Gemfile.lock"], location: "Gemfile.lock") do |source, target|
          difference(source, target, "dependencies.lockfile.platforms")
        end
        rule("missing-lockfile-platform", "Deployment platform is absent from Gemfile.lock", :dependencies, :error,
             impact: "Bundler may resolve dependencies during deployment or reject the bundle.",
             fix: "Add the deployment platform to the lockfile and rebuild the bundle.",
             commands: ["bundle lock --add-platform <required-platform>", "bundle install"], files: ["Gemfile.lock"], location: "Gemfile.lock") do |_source, target, policy|
          platforms = Array(dig(target, "dependencies.lockfile.platforms"))
          required = policy.expected_platforms
          required = [dig(target, "runtime.platform")].compact if required.empty?
          missing = required.reject { |platform| platform_covered?(platforms, platform) }
          !missing.empty? && { "current_platforms" => platforms, "required_platforms" => missing }
        end
        rule("gem-version-drift", "Gem version drift", :dependencies, :warning,
             impact: "Application behavior can differ even when Ruby itself matches.",
             fix: "Use the same committed Gemfile.lock and run bundle install in deployment.", files: ["Gemfile.lock"], location: "Gemfile.lock") do |source, target|
          source_gems = dig(source, "dependencies.gems") || {}
          target_gems = dig(target, "dependencies.gems") || {}
          changes = (source_gems.keys | target_gems.keys).filter_map do |name|
            left = source_gems.dig(name, "version")
            right = target_gems.dig(name, "version")
            { "gem" => name, "source" => left, "target" => right } if left != right
          end
          !changes.empty? && { "changes" => changes }
        end
        rule("git-dependency-drift", "Git-sourced dependency drift", :dependencies, :error,
             impact: "A branch or moving Git reference can resolve different code over time.",
             fix: "Pin Git dependencies to immutable commit SHAs and commit Gemfile.lock.", files: %w[Gemfile Gemfile.lock], location: "Gemfile.lock") do |source, target|
          difference(source, target, "dependencies.lockfile.git_sources")
        end
        rule("path-dependency-in-deployment", "Path dependency detected in deployment", :dependencies, :error,
             impact: "The referenced local path may not exist in CI or production.",
             fix: "Publish the dependency, use a Git source, or vendor it into a stable deployment path.", files: %w[Gemfile Gemfile.lock], location: "Gemfile") do |_source, target|
          paths = Array(dig(target, "dependencies.lockfile.path_sources"))
          deployment = production?(target) || target.key?("container") || dig(target, "operating_system.ci")
          deployment && !paths.empty? && { "paths" => paths.map { |path| Sanitizer.path(path) } }
        end
        rule("prerelease-gem-in-production", "Prerelease gem used in production", :dependencies, :warning,
             impact: "Prerelease gems may change without normal compatibility guarantees.",
             fix: "Pin a stable gem release or explicitly document the production exception.", files: ["Gemfile.lock"], location: "Gemfile.lock") do |_source, target|
          next false unless production?(target)

          gems = selected_gems(target) { |_name, spec| spec["prerelease"] == true }
          !gems.empty? && { "gems" => gems }
        end
        rule("yanked-gem-version", "Yanked gem version detected", :dependencies, :critical,
             impact: "Fresh installations may fail because the exact artifact is no longer served.",
             fix: "Upgrade to an available release and regenerate Gemfile.lock.", files: ["Gemfile.lock"], location: "Gemfile.lock") do |_source, target|
          gems = selected_gems(target) { |_name, spec| spec["yanked"] == true || spec["available"] == false }
          !gems.empty? && { "gems" => gems, "source" => "captured metadata or plugin" }
        end
        rule("missing-native-extension", "Missing native extension", :dependencies, :critical,
             impact: "The gem cannot load its compiled code in the target environment.",
             fix: "Rebuild the extension in the target environment.", commands: ["gem pristine <gem>", "bundle pristine <gem>"], files: ["Gemfile.lock"], location: "Gemfile.lock") do |_source, target|
          gems = selected_gems(target) { |_name, spec| spec["missing_extensions"] == true }
          !gems.empty? && { "gems" => gems }
        end
      end

      def native_library_rules
        library_rule("openssl-incompatibility", "OpenSSL incompatibility", "openssl", :critical,
                     "Use Ruby builds linked to a compatible OpenSSL family in every environment.")
        library_rule("libyaml-mismatch", "libyaml mismatch", "libyaml", :error,
                     "Align libyaml packages and rebuild Ruby or Psych.")
        library_rule("sqlite-version-mismatch", "SQLite version mismatch", "sqlite.runtime", :error,
                     "Install the same SQLite client library and rebuild the sqlite3 gem.")
        library_rule("postgresql-client-mismatch", "PostgreSQL client mismatch", "postgresql.client", :error,
                     "Install the target PostgreSQL client development package and rebuild pg.")
        library_rule("mysql-client-mismatch", "MySQL client mismatch", "mysql.client", :error,
                     "Install the matching MySQL client development package and rebuild mysql2.")
        library_rule("libc-mismatch", "C library mismatch", "libc.family", :critical,
                     "Build native gems against the target libc or use a matching base image.")
        rule("missing-compiler-toolchain", "Compiler toolchain is unavailable", :native, :error,
             impact: "Native gems without a precompiled variant cannot be installed.",
             fix: "Install a C compiler and build tools in the image build stage.") do |_source, target|
          native = selected_gems(target) { |_name, spec| spec["native_extensions"] == true }
          capabilities = dig(target, "operating_system.capabilities") || {}
          missing = %w[make gcc].reject { |tool| capabilities[tool] }
          !native.empty? && !missing.empty? && { "native_gems" => native, "missing_tools" => missing }
        end
        rule("missing-system-headers", "Ruby system headers are unavailable", :native, :error,
             impact: "Native extension compilation may fail before linking.",
             fix: "Install the Ruby development/header package for the target runtime.") do |_source, target|
          headers = dig(target, "operating_system.ruby_headers") || {}
          headers["present"] == false && { "headers" => headers }
        end
        rule("architecture-specific-gem-incompatibility", "Native extension platform mismatch", :native, :critical,
             impact: "The selected gem binary cannot execute on the target platform.",
             fix: "Add the target platform to Gemfile.lock and rebuild gems on that platform.",
             commands: ["bundle lock --add-platform <target-platform>", "bundle install"], files: ["Gemfile.lock"], location: "Gemfile.lock") do |_source, target|
          runtime = dig(target, "runtime.platform").to_s
          gems = selected_gems(target) do |_name, spec|
            platform = spec["platform"].to_s
            spec["native_extensions"] && platform != "ruby" && !platform_covered?([platform], runtime)
          end
          !gems.empty? && { "runtime_platform" => runtime, "gems" => gems }
        end
      end

      def configuration_rules
        rule("missing-environment-variable", "Required environment variable is missing", :configuration, :error,
             impact: "The target application may fail during boot or when the integration is used.",
             fix: "Configure the variable in the target secret/configuration store; do not commit its value.") do |source, target, policy|
          dig(source, "configuration.environment_variables") || {}
          target_vars = dig(target, "configuration.environment_variables") || {}
          required = required_environment_names(source, target)
          missing = required.select { |name| !target_vars[name] && !policy.optional_environment_variable?(name) }
          !missing.empty? && { "variables" => missing }
        end
        rule("environment-variable-local-only", "Environment variable present only locally", :configuration, :warning,
             impact: "Local behavior may rely on configuration unavailable in deployment.",
             fix: "Declare the variable optional in .bootprint.yml or configure it in the target.", location: ".bootprint.yml") do |source, target, policy|
          source_vars = dig(source, "configuration.environment_variables") || {}
          target_vars = dig(target, "configuration.environment_variables") || {}
          required = required_environment_names(source, target)
          names = source_vars.filter_map do |name, value|
            name if value && !target_vars[name] && !required.include?(name) && !policy.optional_environment_variable?(name)
          end
          !names.empty? && { "variables" => names }
        end
        rule("conflicting-environment-variables", "Conflicting environment-variable names", :configuration, :warning,
             impact: "Libraries may select different configuration depending on precedence.",
             fix: "Choose one canonical configuration convention and remove the duplicate.") do |_source, target|
          vars = dig(target, "configuration.environment_variables") || {}
          pairs = [%w[DATABASE_URL DB_HOST], %w[REDIS_URL REDIS_HOST], %w[RAILS_ENV RACK_ENV]]
          conflicts = pairs.select { |left, right| vars[left] && vars[right] }
          !conflicts.empty? && { "conflicts" => conflicts }
        end
        rails_difference("rails-environment-mismatch", "Rails environment mismatch", "environment", :error,
                         "Run both environments with the intended RAILS_ENV and RACK_ENV.")
        rule("debug-mode-in-production", "Debug mode enabled in production", :configuration, :critical,
             impact: "Debug behavior can expose sensitive errors and disable production optimizations.",
             fix: "Disable debug/development settings and use production Rails configuration.") do |_source, target|
          rails = dig(target, "configuration.rails") || {}
          production?(target) && (rails["cache_classes"] == false || rails["eager_load"] == false) && {
            "eager_load" => rails["eager_load"], "cache_classes" => rails["cache_classes"]
          }
        end
        rule("secret-key-configuration-missing", "Rails secret-key configuration is missing", :configuration, :critical,
             impact: "Rails cannot safely verify encrypted cookies and signed messages.",
             fix: "Provide SECRET_KEY_BASE through the deployment secret store.") do |_source, target|
          secret = dig(target, "configuration.rails.secret_key_base") || {}
          production?(target) && secret["present"] == false && { "present" => false, "value_captured" => false }
        end
        rails_difference("database-adapter-mismatch", "Database adapter mismatch", "adapters.database", :error,
                         "Use the same database adapter or test against the production database.")
        rails_difference("cache-adapter-mismatch", "Cache adapter mismatch", "adapters.cache", :warning,
                         "Configure the same cache store or document the intentional difference.")
        rails_difference("queue-adapter-mismatch", "Queue adapter mismatch", "adapters.active_job", :error,
                         "Configure the production Active Job adapter in every relevant environment.")
        rails_difference("session-store-mismatch", "Session store mismatch", "adapters.session", :warning,
                         "Align session-store configuration and migration requirements.")
      end

      def filesystem_rules
        rule("runtime-directory-read-only", "Required runtime directory is read-only", :filesystem, :error,
             impact: "The process may fail when writing caches, sockets, uploads, or runtime state.",
             fix: "Mount a writable directory or redirect runtime files to an approved writable location.") do |_source, target|
          directories = dig(target, "filesystem.required_directories") || {}
          blocked = directories.select { |_name, state| state["present"] && state["writable"] == false }
          !blocked.empty? && { "directories" => blocked }
        end
        rule("temporary-directory-missing", "Temporary directory is unavailable", :filesystem, :critical,
             impact: "Ruby and gems cannot safely create temporary files.",
             fix: "Create a writable temporary directory and configure TMPDIR when necessary.") do |_source, target|
          state = dig(target, "filesystem.temporary_directory") || {}
          (!state["present"] || !state["writable"]) && { "temporary_directory" => state }
        end
        rule("log-directory-not-writable", "Rails log directory is not writable", :filesystem, :error,
             impact: "File logging can fail during application boot or request processing.",
             fix: "Create a writable log directory or log to standard output.") do |_source, target|
          state = dig(target, "filesystem.required_directories.log") || {}
          state["present"] && state["writable"] == false && { "log_directory" => state }
        end
        rule("filesystem-case-sensitivity-mismatch", "Filesystem case sensitivity differs", :filesystem, :warning,
             impact: "Incorrect filename casing can work locally but fail in Linux deployment.",
             fix: "Correct import and require paths to match exact on-disk casing.") do |source, target|
          difference(source, target, "filesystem.case_sensitive")
        end
        rule("path-separator-incompatibility", "Path separator differs", :filesystem, :warning,
             impact: "Hard-coded path separators may create invalid paths on the target OS.",
             fix: "Build paths with File.join and Pathname instead of string concatenation.") do |source, target|
          difference(source, target, "filesystem.path_separator")
        end
        rule("symlink-behavior-mismatch", "Symlink behavior differs", :filesystem, :warning,
             impact: "Deployments or asset pipelines relying on symlinks may fail.",
             fix: "Avoid required symlinks or verify target permissions and filesystem support.") do |source, target|
          difference(source, target, "filesystem.symlinks_supported")
        end
      end

      def initializer_rules
        rule("slow-rails-initializer", "Slow Rails initializer", :rails, :warning,
             impact: "Slow initializers increase deploy, worker, console, and test startup time.",
             fix: "Defer external setup and expensive work until the integration is first used.") do |_source, target|
          threshold = Bootprint.configuration.slow_initializer_threshold_ms
          initializers = Array(dig(target, "configuration.rails.initializers"))
          slow = initializers.select { |item| item["duration_ms"].to_f > threshold }
          !slow.empty? && { "threshold_ms" => threshold, "initializers" => slow }
        end
        rule("unstable-initializer-order", "Rails initializer order changed", :rails, :warning,
             impact: "Configuration may be read before another initializer makes it available.",
             fix: "Declare explicit initializer before/after dependencies or consolidate coupled setup.") do |source, target|
          left = Array(dig(source, "configuration.rails.initializers")).map { |item| item["name"] }
          right = Array(dig(target, "configuration.rails.initializers")).map { |item| item["name"] }
          !left.empty? && !right.empty? && left != right && { "source_order" => left, "target_order" => right }
        end
        rule("initializer-exception", "Rails initializer raised an exception", :rails, :critical,
             impact: "The application cannot complete a reliable boot.",
             fix: "Resolve the recorded exception and avoid swallowing initializer failures.") do |_source, target|
          failed = Array(dig(target, "configuration.rails.initializers")).select { |item| item["exception"] }
          !failed.empty? && { "initializers" => failed }
        end
        rule("initializer-network-operation", "Initializer may perform network operations", :rails, :warning,
             impact: "Network setup during boot makes startup slow and dependent on remote availability.",
             fix: "Defer connection establishment until first use. This finding is heuristic.") do |_source, target|
          networked = Array(dig(target, "configuration.rails.initializers")).select { |item| item["network_operation_heuristic"] }
          !networked.empty? && { "heuristic" => true, "initializers" => networked }
        end
        rule("initializer-missing-environment-variable", "Initializer accessed an unavailable environment variable", :rails, :error,
             impact: "The initializer may configure an integration with a nil or missing value.",
             fix: "Declare the variable required or handle its absence before using the integration.") do |_source, target|
          affected = Array(dig(target, "configuration.rails.initializers")).filter_map do |initializer|
            names = Array(initializer["missing_environment_variables"])
            { "name" => initializer["name"], "variables" => names } unless names.empty?
          end
          !affected.empty? && { "initializers" => affected, "values_captured" => false }
        end
        rule("initializer-global-configuration-mutation", "Initializer mutated global Rails configuration", :rails, :warning,
             impact: "Late global changes can produce ordering-dependent behavior. This finding is heuristic.",
             fix: "Move the setting to environment configuration or declare an explicit initializer dependency.") do |_source, target|
          affected = Array(dig(target, "configuration.rails.initializers")).select do |initializer|
            initializer["configuration_mutation_heuristic"] == true
          end
          !affected.empty? && { "heuristic" => true, "initializers" => affected }
        end
      end

      def rule(id, title, category, severity, impact:, fix:, cause: "The captured environments differ in a compatibility-relevant way.",
               commands: [], files: [], references: [], location: nil, &detector)
        Rules.define id do
          name title
          category category
          severity severity
          detect(&detector)
          explain do |_source, _target, evidence|
            { "title" => title, "summary" => title, "cause" => cause, "impact" => impact, "evidence" => evidence }
          end
          remediate fix, commands: commands, files: files
          references(*references)
          source_location(location) if location
          metadata "built_in" => true, "since" => "0.2.0"
        end
      end

      def library_rule(id, title, path, severity, fix)
        rule(id, title, :native, severity,
             impact: "Native client behavior or binary compatibility may differ.", fix:) do |source, target|
          difference(source, target, "native_libraries.#{path}")
        end
      end

      def rails_difference(id, title, path, severity, fix)
        rule(id, title, :configuration, severity,
             impact: "Rails behavior differs between the source and target environments.", fix:) do |source, target|
          difference(source, target, "configuration.rails.#{path}")
        end
      end

      def difference(source, target, path)
        left = dig(source, path)
        right = dig(target, path)
        !left.nil? && !right.nil? && left != right && { "source" => left, "target" => right }
      end

      def dig(value, path)
        path.split(".").reduce(value) { |current, key| current.is_a?(Hash) ? current[key] : nil }
      end

      def selected_gems(environment, &block)
        gems = dig(environment, "dependencies.gems") || {}
        gems.select(&block).map { |name, spec| { "name" => name, "version" => spec["version"], "platform" => spec["platform"] }.compact }
      end

      def production?(environment)
        dig(environment, "configuration.rails.environment") == "production" || environment["name"] == "production"
      end

      def required_environment_names(source, target)
        explicit = Array(dig(source, "configuration.required_environment_variables")) |
                   Array(dig(target, "configuration.required_environment_variables"))
        source_vars = dig(source, "configuration.environment_variables") || {}
        conventional = %w[DATABASE_URL REDIS_URL SECRET_KEY_BASE RAILS_MASTER_KEY].select { |name| source_vars[name] }
        explicit | conventional
      end

      def platform_covered?(platforms, required)
        return false if required.to_s.empty?

        platforms.any? do |platform|
          platform == required || platform == "ruby" || required.include?(platform) || platform.include?(required)
        end
      end
    end
  end
end
