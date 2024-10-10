# frozen_string_literal: true

require "faraday"
require "json"

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class Client
      USAGE_API_VERSION = "2"
      def initialize(token:, logger:, port: "443", endpoint: "app.graphql-hive.com")
        port = port.to_s
        use_ssl = port == "443"
        scheme = use_ssl ? "https" : "http"
        url = "#{scheme}://#{endpoint}:#{port}"
        @logger = logger
        @connection = setup_connection(url, token, logger)
      end

      def send(path, body, _log_type)
        @connection.post(path) do |req|
          req.body = JSON.generate(body)
        end
      rescue Faraday::Error => e
        @logger.fatal("GraphQL::Hive::Client encountered an error: #{e.message}")
      end

      private

      def setup_connection(url, token, logger)
        Faraday.new(
          url: url,
          headers: build_headers(token)
        ) do |conn|
          conn.request :json
          conn.response :logger, logger, headers: false
          conn.adapter Faraday.default_adapter
        end
      end

      def build_headers(token)
        {
          "Authorization" => token,
          "X-Usage-API-Version" => USAGE_API_VERSION,
          "User-Agent" => "Hive@#{Graphql::Hive::VERSION}",
          "graphql-client-name" => "Hive Ruby Client",
          "graphql-client-version" => Graphql::Hive::VERSION
        }
      end
    end
  end
end
