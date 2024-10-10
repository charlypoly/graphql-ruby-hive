# frozen_string_literal: true

require "spec_helper"

RSpec.describe GraphQL::Hive::Report do
  let(:client_info) { ->(_context) { {name: "test_client"} } }
  let(:schema) { GraphQL::Schema.from_definition("type Query { test: String }") }
  let(:query_string) { "query TestingHive { test }" }
  let(:queries) { [GraphQL::Query.new(schema, query_string, variables: {})] }
  let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: {"data" => {"test" => "test"}})] }
  let(:error_results) do
    [
      GraphQL::Query::Result.new(
        query: queries.first,
        values: {
          "data" => {"test" => "test"},
          "errors" => ["bad stuff"]
        }
      )
    ]
  end
  let(:operations) do
    [
      [Time.now, queries, results, 100],
      [Time.now, queries, error_results, 100]
    ]
  end
  let(:report) {
    described_class.new(operations: operations, client_info: client_info)
  }

  before { Timecop.freeze(Time.now) }
  after { Timecop.return }

  describe "#initialize" do
    it "initializes correctly" do
      expect(report.instance_variable_get(:@operations)).to eq(operations)
      expect(report.instance_variable_get(:@report)).to eq({size: 0, map: {}, operations: []})
      expect(report.instance_variable_get(:@processed)).to eq(false)
      expect(report.instance_variable_get(:@client_info)).to eq(client_info)
    end
  end

  describe "#process_operaions" do
    it "it generates a report" do
      expect(report.process_operations).to eq(
        {
          size: 2,
          map: {
            "8b8412ce86f3ea7accb931b1a5de335d" => {
              fields: ["Query", "Query.test"],
              operationName: "TestingHive",
              operation: "query TestingHive {\n  test\n}"
            }
          },
          operations: [
            {
              operationMapKey: "8b8412ce86f3ea7accb931b1a5de335d",
              timestamp: Time.now.to_i,
              execution: {ok: true, duration: 100, errorsTotal: 0},
              metadata: {client: {name: "test_client"}}
            },
            {
              operationMapKey: "8b8412ce86f3ea7accb931b1a5de335d",
              timestamp: Time.now.to_i,
              execution: {ok: false, duration: 100, errorsTotal: 1},
              metadata: {
                client: {
                  name: "test_client"
                }
              }
            }
          ]
        }
      )
    end
  end

  describe "#to_json" do
    it "is an alias for #process_operations" do
      expect(report.method(:to_json)).to eq(report.method(:process_operations))
    end
  end
end
