# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Hive::UsageReporter do
  let(:subject) { described_class.instance }
  let(:client) { instance_double('Hive::Client') }
  let(:options) do
    {
      logger: logger,
      buffer_size: 1
    }
  end
  let(:logger) { instance_double('Logger') }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:debug)
  end

  describe '#initialize' do
    it 'sets the instance' do
      expect(described_class.instance).to eq(nil)
      described_class.new(options, client)
      expect(described_class.instance).to_not eq(nil)
    end
  end

  describe '#add_operation' do
    it 'adds an operation to the queue' do
      operation = { operation: 'test' }
      described_class.new(options, client)
      subject.add_operation(operation)
      expect(subject.instance_variable_get(:@queue).pop).to eq(operation)
    end
  end

  describe '#on_exit' do
    it 'closes the queue and joins the thread' do
      described_class.new(options, client)
      expect(subject.instance_variable_get(:@queue)).to receive(:close)
      expect(subject.instance_variable_get(:@thread)).to receive(:join)
      subject.on_exit
    end
  end

  describe '#on_start' do
    it 'starts the thread' do
      described_class.new(options, client)
      expect(subject).to receive(:start_thread)
      subject.on_start
    end
  end

  describe '#start_thread' do
    it 'logs a warning if the thread is already alive' do
      described_class.new(options, client)
      subject.instance_variable_set(:@thread, Thread.new { p 'test' })
      expect(logger).to receive(:warn)
      subject.on_start
    end
  end

  describe '#add_operation' do
    let(:timestamp) { 1_720_705_946_333 }
    let(:queries) { [] }
    let(:results) { [] }
    let(:duration) { 100_000 }
    let(:operation) do
      [timestamp, queries, results, duration]
    end
    let(:schema) do
      GraphQL::Schema.from_definition('type Query { test: String }')
    end
    let(:query_string) { 'query TestingHive { test }' }

    it 'adds an operation to the buffer' do
      described_class.new(options, client)
      subject.add_operation(operation)
      expect(subject.instance_variable_get(:@queue).pop).to eq(operation)
    end

    context 'successful operation' do
      let(:options) do
        { logger: logger, buffer_size: 2 }
      end
      let(:queries) do
        [GraphQL::Query.new(schema, query_string, variables: {})]
      end
      let(:results) do
        [GraphQL::Query::Result.new(query: queries.first, values: { 'data' => { 'test' => 'test' } })]
      end

      before do
        allow(client).to receive(:send)
      end

      it 'processes the operations if the buffer is full' do
        described_class.new(options, client)
        subject.add_operation(operation)

        # call process_operation with send
        subject.send(:process_operations, [operation])
        expect(client).to have_received(:send).with(
          '/usage',
          {
            map: { '8b8412ce86f3ea7accb931b1a5de335d' =>
              {
                fields: %w[Query Query.test],
                operation: "query TestingHive {\n  test\n}",
                operationName: 'TestingHive'
              } },
            operations: [
              {
                execution: { duration: 100_000, errors: [], errorsTotal: 0, ok: true },
                operationMapKey: '8b8412ce86f3ea7accb931b1a5de335d',
                timestamp: 1_720_705_946_333
              }
            ],
            size: 1
          },
          :usage
        )
      end
    end
  end
end
