# frozen_string_literal: true

require "logger"
require "securerandom"

require "graphql-hive/version"
require "graphql-hive/usage_reporter"
require "graphql-hive/client"

require "graphql-hive/analyzer"
require "graphql-hive/printer"
require "graphql-hive/reporting_thread"
require "graphql-hive/operations_buffer"
require "graphql-hive/report"
require "graphql-hive/sampler"
require "graphql-hive/sampling/basic_sampler"
require "graphql-hive/sampling/dynamic_sampler"

module GraphQL
  # GraphQL Hive usage collector and schema reporter
  class Hive < GraphQL::Tracing::PlatformTracing
    @@schema = nil
    @@instance = nil

    REPORT_SCHEMA_MUTATION = <<~MUTATION
      mutation schemaPublish($input: SchemaPublishInput!) {
        schemaPublish(input: $input) {
          __typename
        }
      }
    MUTATION

    DEFAULT_OPTIONS = {
      enabled: true,
      debug: false,
      port: "443",
      collect_usage: true,
      read_operations: true,
      report_schema: true,
      buffer_size: 50,
      logger: nil,
      collect_usage_sampling: 1.0
    }.freeze

    self.platform_keys = {
      "lex" => "lex",
      "parse" => "parse",
      "validate" => "validate",
      "analyze_query" => "analyze_query",
      "analyze_multiplex" => "analyze_multiplex",
      "execute_multiplex" => "execute_multiplex",
      "execute_query" => "execute_query",
      "execute_query_lazy" => "execute_query_lazy"
    }

    def initialize(options = {})
      opts = DEFAULT_OPTIONS.merge(options)
      @enabled = opts[:enabled]
      initialize_options!(opts)
      super(opts)
      @@instance = self
      @client = GraphQL::Hive::Client.new(
        token: options[:token],
        port: options[:port],
        endpoint: options[:endpoint],
        logger: @logger
      )
      sampler = GraphQL::Hive::Sampler.new(
        options[:collect_usage_sampling],
        @logger
      )
      buffer = GraphQL::Hive::OperationsBuffer.new(
        queue: Queue.new,
        sampler: sampler,
        client: @client,
        logger: @logger,
        size: opts[:buffer_size],
        client_info: options[:client_info]
      )
      reporting_thread = GraphQL::Hive::ReportingThread.new(
        buffer: buffer,
        logger: @logger
      )
      @usage_reporter = GraphQL::Hive::UsageReporter.new(
        reporting_thread: reporting_thread,
        logger: @logger
      )
      if @enabled
        if opts[:report_schema] && @@schema
          send_report_schema(@@schema)
        end
      end
    end

    def self.instance
      @@instance
    end

    def self.use(schema, **kwargs)
      @@schema = schema
      super
    end

    # called on trace events
    def platform_trace(platform_key, _key, data)
      return yield unless @enabled && @options[:collect_usage]

      if platform_key == "execute_multiplex"
        if data[:multiplex]
          queries = data[:multiplex].queries
          timestamp = (Time.now.utc.to_f * 1000).to_i
          starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          results = yield
          ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed = ending - starting
          duration = (elapsed.to_f * (10**9)).to_i

          report_usage(timestamp, queries, results, duration) unless queries.empty?
          results
        else
          yield
        end
      else
        yield
      end
    end

    # compat
    def platform_authorized_key(type)
      "#{type.graphql_name}.authorized.graphql"
    end

    # compat
    def platform_resolve_type_key(type)
      "#{type.graphql_name}.resolve_type.graphql"
    end

    # compat
    def platform_field_key(type, field)
      "graphql.#{type.name}.#{field.name}"
    end

    def on_exit
      @usage_reporter.on_exit
    end

    def on_start
      @usage_reporter.on_start
    end

    private

    def initialize_options!(options)
      @logger = options[:logger] || default_logger(debug: options[:debug])

      if missing_token?(options)
        @logger.warn("`token` options is missing")
        @enabled = false
        return false
      end

      if missing_reporting_info?(options)
        @logger.warn("`reporting.author` and `reporting.commit` options are required")
        return false
      end

      true
    end

    def missing_token?(options)
      !options.include?(:token) && @enabled
    end

    def missing_reporting_info?(options)
      options[:report_schema] &&
        (
          !options.dig(:reporting, :author) || !options.dig(:reporting, :commit)
        )
    end

    def default_logger(debug: false)
      logger = Logger.new($stderr)
      original_formatter = Logger::Formatter.new
      logger.formatter = proc { |severity, datetime, progname, msg|
        original_formatter.call(severity, datetime, progname, "[hive] #{msg.dump}")
      }
      logger.level = debug ? Logger::DEBUG : Logger::INFO
      logger
    end

    def report_usage(timestamp, queries, results, duration)
      @usage_reporter.add_operation([timestamp, queries, results, duration])
    end

    def send_report_schema(schema)
      sdl = GraphQL::Schema::Printer.new(schema).print_schema

      body = {
        query: REPORT_SCHEMA_MUTATION,
        operationName: "schemaPublish",
        variables: {
          input: {
            sdl: sdl,
            author: @options[:reporting][:author],
            commit: @options[:reporting][:commit],
            service: @options[:reporting][:service_name],
            url: @options[:reporting][:service_url],
            force: true
          }
        }
      }

      @client.send(:"/registry", body, :"report-schema")
    end
  end
end

at_exit do
  GraphQL::Hive.instance&.on_exit
end
