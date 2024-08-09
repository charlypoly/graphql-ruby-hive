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

  let(:timestamp) { 1_720_705_946_333 }
  let(:queries) { [] }
  let(:results) { [] }
  let(:duration) { 100_000 }
  let(:operation) { [timestamp, queries, results, duration] }

  let(:schema) { GraphQL::Schema.from_definition('type Query { test: String }') }
  let(:query_string) { 'query TestingHive { test }' }

  before do
    allow(logger).to receive(:warn)
    allow(logger).to receive(:debug)
  end

  describe '#initialize' do
    after do
      subject.on_exit
    end

    it 'sets the instance' do
      expect(described_class.instance).to eq(nil)
      described_class.new(options, client)
      expect(described_class.instance).to_not eq(nil)
    end

    context 'when provided a sampler' do
      let(:options) do
        {
          logger: logger,
          buffer_size: 1,
          collect_usage_sampler: Proc.new {}
        }
      end

      it 'creates the sampler' do
        described_class.new(options, client)
        expect(subject.instance_variable_get(:@sampler)).to be_an_instance_of(GraphQL::Hive::DynamicSampler)
      end
    end
  end

  describe '#add_operation' do
    after do
      subject.on_exit
    end
    
    it 'adds an operation to the queue' do
      operation = { operation: 'test' }
      described_class.new(options, client)
      subject.add_operation(operation)
      expect(subject.instance_variable_get(:@queue).pop).to eq(operation)
    end
  end

  describe '#on_exit' do
    after do
      subject.on_exit
    end

    it 'closes the queue and joins the thread' do
      described_class.new(options, client)
      expect(subject.instance_variable_get(:@queue)).to receive(:close)
      expect(subject.instance_variable_get(:@thread)).to receive(:join)
    end
  end

  describe '#on_start' do
    after do
      subject.on_exit
    end

    it 'starts the thread' do
      described_class.new(options, client)
      expect(subject).to receive(:start_thread)
      subject.on_start
    end
  end

  describe '#start_thread' do
    after do
      subject.on_exit
    end
    
    it 'logs a warning if the thread is already alive' do
      described_class.new(options, client)
      subject.instance_variable_set(:@thread, Thread.new {})
      expect(logger).to receive(:warn)
      subject.on_start
    end
    
    context 'when provided a sampler' do
      let(:sampler_class) { class_double(GraphQL::Hive::DynamicSampler).as_stubbed_const }
      let(:sampler_instance) { instance_double('GraphQL::Hive::DynamicSampler') }

      let(:options) do
        {
          logger: logger,
          buffer_size: 1,
          collect_usage_sampler: Proc.new {}
        }
      end

      before do
        allow(sampler_class).to receive(:new).and_return(sampler_instance)
        allow(client).to receive(:send)
      end

      it 'reports the operation if it should be included' do
        allow(sampler_instance).to receive(:sample?).and_return(true)

        described_class.new(options, client)
        subject.add_operation(operation)
        subject.on_start
        subject.on_exit
        
        expect(sampler_instance).to have_received(:sample?).with(operation)
        expect(client).to have_received(:send)
      end

      it 'does not report the operation if it should not be included' do
        allow(sampler_instance).to receive(:sample?).and_return(false)

        described_class.new(options, client)
        subject.add_operation(operation)
        subject.on_start
        subject.on_exit

        expect(sampler_instance).to have_received(:sample?).with(operation)
        expect(client).not_to have_received(:send)
      end

      it 'reports the operation but logs a warning if sampler is invalid' do
        allow(sampler_instance).to receive(:sample?).and_raise(StandardError.new('some_error'))

        described_class.new(options, client)
        subject.add_operation(operation)
        subject.on_start
        subject.on_exit

        expect(logger).to have_received(:warn).with('All operations are sampled because sampling configuration contains an error: some_error')
        expect(sampler_instance).to have_received(:sample?).with(operation)
        expect(client).to have_received(:send)
      end
    end
  end

  describe '#process_operation' do
    let(:queries) { [GraphQL::Query.new(schema, query_string, variables: {})]}
    let(:results) { [GraphQL::Query::Result.new(query: queries.first, values: { 'data' => { 'test' => 'test' } })] }

    before do
      allow(client).to receive(:send)
    end

    after do
      subject.on_exit
    end

    it 'processes and reports the operation to the client' do
      described_class.new(options, client)
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