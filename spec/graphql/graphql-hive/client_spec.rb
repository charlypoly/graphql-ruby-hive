# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::Client do
  let(:token) { "test-token" }
  let(:logger) { Logger.new(nil) }
  let(:client) { described_class.new(token: token, logger: logger) }
  let(:path) { "/test-path" }
  let(:url) { "https://app.graphql-hive.com:443#{path}" }
  let(:example_payload) {
    JSON.parse(
      File.read(
        File.join(__dir__, "fixtures", "example_payload.json")
      )
    )
  }
  before do
    stub_request(:post, url)
      .with(
        headers: {
          "Authorization" => token,
          "X-Usage-API-Version" => described_class::USAGE_API_VERSION,
          "User-Agent" => "Hive@#{Graphql::Hive::VERSION}",
          "graphql-client-name" => "Hive Ruby Client",
          "graphql-client-version" => Graphql::Hive::VERSION
        },
        body: JSON.generate(example_payload)
      )
      .to_return(status: 200, body: '{"success":true}', headers: {})
  end

  describe "#send" do
    it "sends a POST request with the correct headers and body" do
      client.send(path, example_payload, "log_type")

      expect(WebMock).to have_requested(:post, url)
        .with(
          headers: {
            "Authorization" => token,
            "X-Usage-API-Version" => described_class::USAGE_API_VERSION,
            "User-Agent" => "Hive@#{Graphql::Hive::VERSION}",
            "graphql-client-name" => "Hive Ruby Client",
            "graphql-client-version" => Graphql::Hive::VERSION
          },
          body: JSON.generate(example_payload)
        ).once
    end

    context "when an error occurs" do
      before do
        stub_request(:post, url).to_raise(Faraday::ConnectionFailed.new("Connection failed"))
      end

      it "logs the error" do
        expect(logger).to receive(:fatal).with(/GraphQL::Hive::Client encountered an error: Connection failed/)
        client.send(path, example_payload, "log_type")
      end
    end
  end
end
