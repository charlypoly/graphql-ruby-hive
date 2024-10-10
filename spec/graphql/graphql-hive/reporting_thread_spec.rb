require "spec_helper"

RSpec.describe GraphQL::Hive::ReportingThread do
  let(:logger) { instance_double("Logger", warn: nil, error: nil) }
  let(:queue) { Queue.new }
  let(:sampler) { GraphQL::Hive::Sampler.new(1, logger) }
  let(:client) {
    GraphQL::Hive::Client.new(
      token: "Bearer test-token",
      logger: logger
    )
  }
  let(:buffer) do
    GraphQL::Hive::OperationsBuffer.new(
      queue: queue,
      sampler: sampler,
      logger: logger,
      client: client,
      size: 2
    )
  end
  let(:reporting_thread) do
    described_class.new(buffer: buffer, logger: logger)
  end

  describe "#initialize" do
    it "initializes with the correct instance variables" do
      expect(reporting_thread.instance_variable_get(:@buffer)).to be(buffer)
      expect(reporting_thread.instance_variable_get(:@logger)).to be(logger)
    end
  end

  describe "#start_thread" do
    context "when thread is not alive" do
      it "starts a new thread" do
        expect(Thread).to receive(:new).and_call_original
        reporting_thread.start_thread
        expect(reporting_thread.instance_variable_get(:@thread)).to be_a(Thread)
      end
    end

    context "when thread is already alive" do
      it "logs a warning and does not start a new thread" do
        reporting_thread.start_thread
        expect(logger).to receive(:warn).with("Tried to start operations flushing thread but it was already alive")
        reporting_thread.start_thread
      end
    end

    context "when an error occurs in the thread" do
      it "logs the error" do
        mutex = Mutex.new
        condition = ConditionVariable.new

        buffer = reporting_thread.instance_variable_get(:@buffer)
        allow(buffer).to receive(:run).and_raise(StandardError.new("Test error"))
        allow(logger).to receive(:error) do |error|
          mutex.synchronize { condition.signal }
        end
        mutex.synchronize do
          reporting_thread.start_thread
          condition.wait(mutex)
        end
        expect(logger).to have_received(:error).with(
          instance_of(StandardError)
        )
      end
    end
  end

  describe "#join_thread" do
    it "joins the thread" do
      reporting_thread.start_thread
      expect(reporting_thread.instance_variable_get(:@thread)).to receive(:join)
      reporting_thread.join_thread
    end
  end
end
