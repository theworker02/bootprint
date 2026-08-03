# frozen_string_literal: true

require "optparse"
require "json"
require_relative "../bootprint"
require_relative "formatters"

module Bootprint
  class CLI
    EXIT_OK = 0
    EXIT_POLICY = 1
    EXIT_CONFIG = 2
    EXIT_SNAPSHOT = 3
    EXIT_INTERNAL = 4

    def self.start(argv = ARGV, out: $stdout, err: $stderr)
      new(argv, out:, err:).run
    end

    def initialize(argv, out:, err:)
      @argv = argv.dup
      @out = out
      @err = err
    end

    def run
      command = @argv.shift
      case command
      when "capture" then capture
      when "diff" then diff
      when "diagnose" then diagnose
      when "doctor" then doctor
      when "verify" then verify
      when "fix" then fix
      when "policy" then policy_command
      when "snapshot" then snapshot_command
      when "docker" then docker_command
      when "ci" then ci_command
      when "security" then security_command
      when "version", "--version", "-v" then version
      when "help", "--help", "-h", nil then help(EXIT_OK)
      else
        @err.puts "Unknown command: #{command}"
        help(EXIT_CONFIG)
      end
    rescue InvalidSnapshotError => error
      @err.puts "bootprint: #{error.message}"
      EXIT_SNAPSHOT
    rescue OptionParser::ParseError, ConfigurationError => error
      @err.puts "bootprint: #{error.message}"
      EXIT_CONFIG
    rescue DockerError, PluginError, Errno::EACCES, Errno::ENOENT => error
      @err.puts "bootprint: #{error.message}"
      EXIT_INTERNAL
    rescue StandardError => error
      @err.puts "bootprint: internal error: #{error.class}: #{Sanitizer.text(error.message)}"
      @err.puts error.backtrace if ENV["BOOTPRINT_DEBUG"] == "1"
      EXIT_INTERNAL
    end

    private

    def capture
      options = { env_names: [], required_env: [], privacy: "standard" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bootprint capture [NAME] [options]"
        opts.on("-o", "--output PATH", "Write to PATH") { |value| options[:output] = value }
        opts.on("--env NAME", "Include an environment-variable name") { |value| options[:env_names] << value }
        opts.on("--required-env NAME", "Declare a required environment variable") { |value| options[:required_env] << value }
        opts.on("--all-env", "Record every environment-variable name; never values") { options[:all_env] = true }
        opts.on("--privacy MODE", %w[standard strict], "standard or strict") { |value| options[:privacy] = value }
        opts.on("--policy PATH", "Apply capture policy") { |value| options[:policy] = value }
      end
      return EXIT_OK unless parse_options(parser)

      label = @argv.shift
      reject_extra_arguments!
      validate_label!(label)
      policy = load_policy(options[:policy])
      policy.apply!
      Bootprint.configuration.environment_names |= options[:env_names]
      Bootprint.configuration.required_environment_names |= options[:required_env]
      Bootprint.configuration.environment_patterns = [/.*/] if options[:all_env]
      output = options[:output] || snapshot_path(label)
      Snapshot.capture(label:, privacy: options[:privacy]).write(output)
      @out.puts "Captured sanitized schema-v#{Schema::CURRENT_VERSION} runtime fingerprint to #{output}"
      EXIT_OK
    end

    def diff
      options = report_options
      parser = report_parser("Usage: bootprint diff SOURCE TARGET [options]", options)
      return EXIT_OK unless parse_options(parser)
      raise OptionParser::MissingArgument, "SOURCE and TARGET are required" unless @argv.length == 2

      source = load_snapshot(@argv.shift)
      target = load_snapshot(@argv.shift)
      policy = load_policy(options[:policy])
      changes = Diff.new(source, target, allowed_paths: policy.allowed_paths + options[:allows]).changes
      findings = changes.map { |change| raw_change_finding(change) }
      report = Report.new(source:, target:, findings:, policy:, duration_ms: 0.0)
      render(report, options[:format])
      EXIT_OK
    end

    def diagnose
      options = report_options.merge(against: nil)
      parser = report_parser("Usage: bootprint diagnose SOURCE TARGET [options]", options)
      parser.on("--against SNAPSHOT", "Compare SNAPSHOT with the current environment") { |value| options[:against] = value }
      return EXIT_OK unless parse_options(parser)

      source, target = diagnosis_pair(options)
      report = build_diagnosis(source, target, options)
      render(report, options[:format])
      report.blocking? ? EXIT_POLICY : EXIT_OK
    end

    def doctor
      options = report_options.merge(against: nil)
      parser = report_parser("Usage: bootprint doctor [options]", options)
      parser.on("--against SNAPSHOT", "Include drift diagnosis from SNAPSHOT") { |value| options[:against] = value }
      return EXIT_OK unless parse_options(parser)

      reject_extra_arguments!
      policy = load_policy(options[:policy]).apply!
      current = Snapshot.capture(label: "current")
      source = options[:against] ? load_snapshot(options[:against]) : current
      report = Diagnosis.new(source, current, policy:, only: options[:only], minimum_severity: options[:minimum]).run
      render(report, options[:format])
      report.blocking? ? EXIT_POLICY : EXIT_OK
    end

    def verify
      options = report_options.merge(against: "bootprint.lock")
      parser = report_parser("Usage: bootprint verify [options]", options)
      parser.on("--against SNAPSHOT", "Reference snapshot (default: bootprint.lock)") { |value| options[:against] = value }
      return EXIT_OK unless parse_options(parser)

      reject_extra_arguments!
      source = load_snapshot(options[:against])
      policy = load_policy(options[:policy]).apply!
      target = Snapshot.capture(label: "current")
      report = Diagnosis.new(source, target, policy:, only: options[:only], minimum_severity: options[:minimum]).run
      render(report, options[:format])
      report.blocking? ? EXIT_POLICY : EXIT_OK
    end

    def fix
      options = report_options.merge(against: "bootprint.lock", dry_run: false)
      parser = report_parser("Usage: bootprint fix --dry-run [options]", options)
      parser.on("--against SNAPSHOT", "Reference snapshot") { |value| options[:against] = value }
      parser.on("--dry-run", "Preview remediation without modifying files") { options[:dry_run] = true }
      return EXIT_OK unless parse_options(parser)
      raise OptionParser::MissingArgument, "--dry-run is required; automatic repair is not supported" unless options[:dry_run]

      reject_extra_arguments!
      source = load_snapshot(options[:against])
      policy = load_policy(options[:policy]).apply!
      report = Diagnosis.new(source, Snapshot.capture(label: "current"), policy:).run
      @out.puts "Bootprint remediation preview (no commands executed, no files modified)"
      report.findings.reject(&:suppressed).each do |finding|
        remediation = finding.remediation || {}
        next if remediation.empty?

        @out.puts "\n#{finding.severity.to_s.upcase} #{finding.title}"
        @out.puts "  #{remediation['summary']}" if remediation["summary"]
        Array(remediation["commands"]).each { |command| @out.puts "  would run: #{command}" }
        Array(remediation["files"]).each { |file| @out.puts "  may update: #{file}" }
      end
      EXIT_OK
    end

    def policy_command
      subcommand = @argv.shift
      options = { path: default_policy_path }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bootprint policy #{subcommand || 'COMMAND'} [--file PATH]"
        opts.on("--file PATH", "Policy file (default: .bootprint.yml)") { |value| options[:path] = value }
      end
      return EXIT_OK unless parse_options(parser)

      reject_extra_arguments!
      policy = Policy.load(options[:path])
      case subcommand
      when "validate"
        @out.puts "Policy is valid: #{policy.path}"
      when "explain"
        @out.write policy.explain
      else
        raise OptionParser::InvalidArgument, "policy command must be validate or explain"
      end
      EXIT_OK
    end

    def snapshot_command
      subcommand = @argv.shift
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bootprint snapshot #{subcommand || 'COMMAND'} SNAPSHOT [options]"
        opts.on("-o", "--output PATH", "Migration output path") { |value| options[:output] = value }
      end
      return EXIT_OK unless parse_options(parser)

      reference = @argv.shift or raise OptionParser::MissingArgument, "SNAPSHOT is required"
      reject_extra_arguments!
      path = resolve_snapshot(reference)
      snapshot = Snapshot.load(path)
      case subcommand
      when "inspect"
        @out.puts JSON.pretty_generate(snapshot_inspection(snapshot, path))
      when "validate"
        @out.puts "Snapshot is valid: #{File.expand_path(path)} (schema #{snapshot.data['schema_version']})"
      when "migrate"
        output = options[:output] || "#{path}.v#{Schema::CURRENT_VERSION}.json"
        snapshot.write(output)
        @out.puts "Migrated snapshot to #{output}"
      else
        raise OptionParser::InvalidArgument, "snapshot command must be inspect, migrate, or validate"
      end
      EXIT_OK
    end

    def docker_command
      require_relative "docker"
      subcommand = @argv.shift
      options = report_options.merge(against: nil, privacy: "standard")
      parser = report_parser("Usage: bootprint docker #{subcommand || 'COMMAND'} IMAGE [options]", options)
      parser.on("--against SNAPSHOT", "Reference snapshot") { |value| options[:against] = value }
      parser.on("-o", "--output PATH", "Capture output path") { |value| options[:output] = value }
      parser.on("--privacy MODE", %w[standard strict], "standard or strict") { |value| options[:privacy] = value }
      return EXIT_OK unless parse_options(parser)

      image = @argv.shift or raise OptionParser::MissingArgument, "IMAGE is required"
      reject_extra_arguments!
      target = Docker::Client.new.capture(image, privacy: options[:privacy])
      case subcommand
      when "capture"
        output = options[:output] || File.join(".bootprint", "#{safe_name(image)}.json")
        target.write(output)
        @out.puts "Captured Docker image #{image} to #{output}"
        EXIT_OK
      when "compare", "diagnose"
        source = load_snapshot(options[:against] || "bootprint.lock")
        report = build_diagnosis(source, target, options)
        render(report, options[:format])
        report.blocking? ? EXIT_POLICY : EXIT_OK
      else
        raise OptionParser::InvalidArgument, "docker command must be capture, compare, or diagnose"
      end
    end

    def ci_command
      subcommand = @argv.shift
      raise OptionParser::InvalidArgument, "ci command must be verify" unless subcommand == "verify"

      options = report_options.merge(against: "bootprint.lock")
      parser = report_parser("Usage: bootprint ci verify [options]", options)
      parser.on("--against SNAPSHOT", "Reference snapshot") { |value| options[:against] = value }
      return EXIT_OK unless parse_options(parser)

      reject_extra_arguments!
      source = load_snapshot(options[:against])
      policy = load_policy(options[:policy]).apply!
      target = Snapshot.capture(label: ci_provider)
      report = Diagnosis.new(source, target, policy:, only: options[:only], minimum_severity: options[:minimum]).run
      render(report, options[:format])
      emit_ci_annotations(report)
      report.blocking? ? EXIT_POLICY : EXIT_OK
    end

    def security_command
      subcommand = @argv.shift
      raise OptionParser::InvalidArgument, "security command must be audit" unless subcommand == "audit"

      options = { format: "human" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: bootprint security audit SNAPSHOT [--format human|json]"
        opts.on("--format FORMAT", %w[human json]) { |value| options[:format] = value }
      end
      return EXIT_OK unless parse_options(parser)

      reference = @argv.shift or raise OptionParser::MissingArgument, "SNAPSHOT is required"
      reject_extra_arguments!
      require_relative "security/auditor"
      issues = Security::Auditor.new(load_snapshot(reference)).audit
      if options[:format] == "json"
        @out.puts JSON.pretty_generate("schema_version" => 1, "issues" => issues.map(&:to_h))
      elsif issues.empty?
        @out.puts "Security audit passed: no likely sensitive values detected."
      else
        @out.puts "Security audit found #{issues.length} potential exposure(s):"
        issues.each { |issue| @out.puts "WARNING #{issue.path}: #{issue.message}" }
      end
      issues.empty? ? EXIT_OK : EXIT_POLICY
    end

    def report_options
      { format: "human", allows: [], policy: default_policy_path, only: nil, minimum: nil }
    end

    def report_parser(banner, options)
      OptionParser.new do |opts|
        opts.banner = banner
        opts.on("--format FORMAT", %w[human json sarif markdown], "human, json, sarif, or markdown") { |value| options[:format] = value }
        opts.on("--only CATEGORIES", "Comma-separated rule categories") { |value| options[:only] = value.split(",").map(&:strip) }
        opts.on("--minimum-severity LEVEL", Rules::Rule::SEVERITIES.map(&:to_s)) { |value| options[:minimum] = value }
        opts.on("--allow PATH", "Allow a dotted raw-diff path") { |value| options[:allows] << value }
        opts.on("--policy PATH", "Policy file") { |value| options[:policy] = value }
      end
    end

    def diagnosis_pair(options)
      if options[:against]
        reject_extra_arguments!
        load_policy(options[:policy]).apply!
        [load_snapshot(options[:against]), Snapshot.capture(label: "current", privacy: Bootprint.configuration.privacy)]
      else
        raise OptionParser::MissingArgument, "SOURCE and TARGET are required unless --against is used" unless @argv.length == 2

        [load_snapshot(@argv.shift), load_snapshot(@argv.shift)]
      end
    end

    def build_diagnosis(source, target, options)
      policy = load_policy(options[:policy]).apply!
      Diagnosis.new(source, target, policy:, only: options[:only], minimum_severity: options[:minimum]).run
    end

    def raw_change_finding(change)
      Rules::Finding.new(
        rule_id: "raw-environment-difference", title: change.path, category: :difference,
        severity: :info, summary: "#{change.path} differs between snapshots.",
        evidence: { "source" => change.local, "target" => change.target },
        remediation: { "summary" => "Run bootprint diagnose for compatibility guidance.", "commands" => [], "files" => [] },
        references: [], metadata: {}, suppressed: false
      )
    end

    def render(report, format)
      @out.write Formatters.render(format, report, color: color?)
    end

    def emit_ci_annotations(report)
      provider = ci_provider
      if provider == "github"
        report.findings.reject(&:suppressed).each do |finding|
          level = %i[critical error].include?(finding.severity) ? "error" : "warning"
          @out.puts "::#{level} title=#{escape_annotation(finding.title)}::#{escape_annotation(finding.summary)}"
        end
        if ENV["GITHUB_STEP_SUMMARY"] && !ENV["GITHUB_STEP_SUMMARY"].empty?
          File.open(ENV["GITHUB_STEP_SUMMARY"], "a", encoding: "UTF-8") do |file|
            file.write Formatters::Markdown.new(report).render
          end
        end
      elsif provider == "gitlab"
        @out.puts "Bootprint GitLab CI: #{report.blocking? ? 'policy violation' : 'compatible'}"
      end
    end

    def ci_provider
      return "github" if ENV["GITHUB_ACTIONS"] == "true"
      return "gitlab" if ENV["GITLAB_CI"] == "true"
      return "circleci" if ENV["CIRCLECI"] == "true"

      ENV.key?("CI") ? "generic" : "local"
    end

    def escape_annotation(value)
      value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
    end

    def snapshot_inspection(snapshot, path)
      {
        "path" => File.expand_path(path),
        "schema_version" => snapshot.data["schema_version"],
        "generated_at" => snapshot.data["generated_at"],
        "bootprint_version" => snapshot.data["bootprint_version"],
        "environment_name" => snapshot.name,
        "sections" => snapshot.environment.keys.sort,
        "capture" => snapshot.data["capture"]
      }
    end

    def load_policy(path)
      Policy.load(path)
    end

    def default_policy_path
      File.file?(".bootprint.yml") ? ".bootprint.yml" : nil
    end

    def load_snapshot(reference) = Snapshot.load(resolve_snapshot(reference))

    def resolve_snapshot(reference)
      return reference if File.file?(reference)

      named = File.join(".bootprint", "#{reference}.json")
      File.file?(named) ? named : reference
    end

    def snapshot_path(label) = label ? File.join(".bootprint", "#{label}.json") : "bootprint.lock"

    def validate_label!(label)
      return unless label

      valid = label.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_.-]*\z/) && !%w[. ..].include?(label)
      raise OptionParser::InvalidArgument, "NAME may contain only letters, numbers, dots, underscores, and hyphens" unless valid
    end

    def safe_name(value) = value.to_s.gsub(/[^a-zA-Z0-9_.-]+/, "-").gsub(/\A-++|-++\z/, "")

    def reject_extra_arguments!
      raise OptionParser::ParseError, "unexpected arguments: #{@argv.join(' ')}" unless @argv.empty?
    end

    def parse_options(parser)
      parser.on_tail("-h", "--help", "Show help") do
        @out.puts(parser)
        throw :bootprint_help
      end
      catch(:bootprint_help) do
        parser.parse!(@argv)
        return true
      end
      false
    end

    def color? = @out.respond_to?(:tty?) && @out.tty? && !ENV.key?("NO_COLOR")

    def version
      @out.puts "bootprint #{VERSION}"
      EXIT_OK
    end

    def help(exit_code)
      @out.puts <<~HELP
        Bootprint #{VERSION} — Reproduce the environment, not just the dependencies.

        Usage: bootprint COMMAND [options]

          capture [NAME]          Capture a sanitized schema-v2 snapshot
          diff SOURCE TARGET      Show every raw environment difference
          diagnose SOURCE TARGET  Explain compatibility risks and fixes
          doctor                  Diagnose the current runtime
          verify                  Enforce policy against bootprint.lock
          fix --dry-run           Preview remediation without modifying files
          policy COMMAND          Validate or explain .bootprint.yml
          snapshot COMMAND        Inspect, migrate, or validate snapshots
          docker COMMAND          Capture, compare, or diagnose a local Docker image
          ci verify               Verify with CI-native annotations
          security audit          Audit a snapshot for sensitive data

        Run `bootprint COMMAND --help` for command-specific options.
      HELP
      exit_code
    end
  end
end
