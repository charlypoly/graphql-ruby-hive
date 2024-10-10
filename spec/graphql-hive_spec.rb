require "spec_helper"

RSpec.describe GraphQL::Hive do
  describe "#initialize with defaults" do
    let(:hive) { GraphQL::Hive.new }

    it "initializes with default values" do
      expect(hive.instance_variable_get(:@client)).to be_a(GraphQL::Hive::Client)
      expect(hive.instance_variable_get(:@usage_reporter)).to be_a(GraphQL::Hive::UsageReporter)
      expect(hive.instance_variable_get(:@enabled)).to eq(false)
    end
  end

  describe "#initialize with custom values" do
    let(:options) {
      {token: "token",
       port: 1234,
       endpoint: "http://localhost:1234",
       logger: Logger.new(IO::NULL),
       enabled: true,
       collect_usage: true}
    }
    let(:hive) { GraphQL::Hive.new(options) }

    it "initializes with the provided values" do
      expect(hive.instance_variable_get(:@client)).to be_a(GraphQL::Hive::Client)
      expect(hive.instance_variable_get(:@usage_reporter)).to be_a(GraphQL::Hive::UsageReporter)
      expect(hive.instance_variable_get(:@enabled)).to eq(true)
    end
  end
end
