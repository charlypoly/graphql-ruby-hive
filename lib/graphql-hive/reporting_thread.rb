# frozen_string_literal: true

require "forwardable"

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class ReportingThread
      extend Forwardable

      def_delegators :@buffer, :push

      def initialize(buffer:, logger:)
        @buffer = buffer
        @logger = logger
      end

      def start_thread
        if @thread&.alive?
          @logger.warn("Tried to start operations flushing thread but it was already alive")
          return
        end

        @thread = Thread.new do
          @buffer.run
        rescue => e
          @logger.error(e)
        end
      end

      def join_thread
        @buffer.close
        @thread&.join
      end
    end
  end
end
