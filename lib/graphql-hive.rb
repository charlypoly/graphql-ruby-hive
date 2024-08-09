# frozen_string_literal: true

require 'logger'
require 'securerandom'

require 'graphql-hive/version'
require 'graphql-hive/client'

require 'graphql-hive/usage_reporter'
require 'graphql-hive/basic_sampler'
require 'graphql-hive/dynamic_sampler'

# class MySchema < GraphQL::Schema
#   use(
#     GraphQL::Hive,
#     {
#       token: 'YOUR-TOKEN',
#       collect_usage: true,
#       report_schema: true,
#       enabled: true, // Enable/Disable Hive Client
#       debug: true, // Debugging mode
#       logger: MyLogger.new,
#       endpoint: 'app.graphql-hive.com',
#       port: 80,
#       reporting: {
#         author: 'Author of the latest change',
#         commit: 'git sha or any identifier',
#         service_name: '',
#         service_url: '',
#       },
#       client_info: Proc.new { |context| { name: context.client_name, version: context.client_version } }
#     }
#   )
#
#   # ...
#
# end

module GraphQL
  # GraphQL Hive usage collector and schema reporter
  class Hive < GraphQL::Tracing::PlatformTracing
    @@schema = nil
    @@instance = nil

    @usage_reporter = nil
    @client = nil

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
      port: '443',
      collect_usage: true,
      read_operations: true,
      report_schema: true,
      buffer_size: 50,
      logger: nil,
      collect_usage_sampling: 1.0
    }.freeze

    self.platform_keys = {
      'lex' => 'lex',
      'parse' => 'parse',
      'validate' => 'validate',
      'analyze_query' => 'analyze_query',
      'analyze_multiplex' => 'analyze_multiplex',
      'execute_multiplex' => 'execute_multiplex',
      'execute_query' => 'execute_query',
      'execute_query_lazy' => 'execute_query_lazy'
    }

    def initialize(options = {})
      opts = DEFAULT_OPTIONS.merge(options)
      initialize_options!(opts)
      super(opts)

      @@instance = self

      @client = GraphQL::Hive::Client.new(opts)
      @usage_reporter = GraphQL::Hive::UsageReporter.new(opts, @client)

      # buffer
      @report = {
        size: 0,
        map: {},
        operations: []
      }

      send_report_schema(@@schema) if @@schema && opts[:report_schema] && @options[:enabled]
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
      return yield unless @options[:enabled] && @options[:collect_usage]

      if platform_key == 'execute_multiplex'
        if data[:multiplex]
          queries = data[:multiplex].queries
          timestamp = (Time.now.utc.to_f * 1000).to_i
          starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          results = yield
          ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          elapsed = ending - starting
          duration = (elapsed.to_f * (10**9)).to_i

          report_usage(timestamp, queries, results, duration) if !queries.empty?
          
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
      if options[:logger].nil?
        options[:logger] = Logger.new($stderr)
        original_formatter = Logger::Formatter.new
        options[:logger].formatter = proc { |severity, datetime, progname, msg|
          original_formatter.call(severity, datetime, progname, "[hive] #{msg.dump}")
        }
        options[:logger].level = options[:debug] ? Logger::DEBUG : Logger::INFO
      end
      if !options.include?(:token) && (!options.include?(:enabled) || options.enabled)
        options[:logger].warn('`token` options is missing')
        options[:enabled] = false
        false
      elsif options[:report_schema] &&
            (
              !options.include?(:reporting) ||
              (
                options.include?(:reporting) && (
                  !options[:reporting].include?(:author) || !options[:reporting].include?(:commit)
                )
              )
            )

        options[:logger].warn('`reporting.author` and `reporting.commit` options are required')
        false
      end
      true
    end

    def report_usage(timestamp, queries, results, duration)
      @usage_reporter.add_operation([timestamp, queries, results, duration])
    end

    def send_report_schema(schema)
      sdl = GraphQL::Schema::Printer.new(schema).print_schema

      body = {
        query: REPORT_SCHEMA_MUTATION,
        operationName: 'schemaPublish',
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

      @client.send('/registry', body, :'report-schema')
    end
  end
end

at_exit do
  GraphQL::Hive.instance&.on_exit
end
