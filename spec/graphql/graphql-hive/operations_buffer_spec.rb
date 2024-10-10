require "spec_helper"

RSpec.describe GraphQL::Hive::OperationsBuffer do
  let(:logger) { instance_double("Logger", debug: nil) }
  let(:queue) { Queue.new }
  let(:sampler) { double("Sampler", sample?: true) }
  let(:client) { instance_double("GraphQL::Hive::Client") }
  let(:buffer) do
    described_class.new(
      queue: queue,
      sampler: sampler,
      client: client,
      logger: logger,
      size: 2,
      client_info: ->(_context) { {name: "test_client"} }
    )
  end
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

  describe "#initialize" do
    it "initializes with the correct instance variables" do
      expect(buffer.instance_variable_get(:@buffer)).to be_a(Array).and be_empty
      expect(buffer.instance_variable_get(:@mutex)).to be_a(Mutex)
      expect(buffer.instance_variable_get(:@queue)).to eq(queue)
      expect(buffer.instance_variable_get(:@sampler)).to eq(sampler)
      expect(buffer.instance_variable_get(:@client)).to be(client)
    end
  end

  describe "#run" do
    let(:client) { instance_double("GraphQL::Hive::Client", send: nil) }
    let(:signal_queue) { Queue.new }

    before do
      allow(GraphQL::Hive::Client).to receive(:new).and_return(client)
    end

    it "loops through the queue and publishes operations" do
      mutex = Mutex.new
      condition = ConditionVariable.new

      queue_thread = Thread.new { buffer.run }

      operations_thread = Thread.new do
        mutex.synchronize do
          # Add operation to the queue
          queue.push(operations.pop)
          # Tell the test thread to continue
          condition.signal
          # Wait for control to be returned
          condition.wait(mutex)
          # Add operation to the queue
          queue.push(operations.pop)
          # Tell the test thread to continue
          condition.signal
        end
      end

      mutex.synchronize do
        # Wait for data in the buffer
        condition.wait(mutex)
        expect(buffer.instance_variable_get(:@buffer).size).to eq(1)
        # Tell the operations thread to continue
        condition.signal
        # Wait for the last push
        condition.wait(mutex)
        expect(client).to have_received(:send).with(
          :"/usage",
          hash_including(size: 2),
          :usage
        ).once
      end

      expect(buffer.instance_variable_get(:@buffer).size).to eq(0)

      queue.close
      queue_thread.join
      operations_thread.join
    end
  end
end
