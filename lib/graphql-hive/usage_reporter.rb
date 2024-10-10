# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class UsageReporter
      @@instance = nil

      def self.instance
        @@instance
      end

      def initialize(reporting_thread:, logger:)
        @@instance = self
        @reporting_thread = reporting_thread
        @logger = logger
      end

      def add_operation(operation)
        @reporting_thread.push(operation)
      end

      def on_exit
        @logger.debug("Shutting down usage reporter")
        @reporting_thread.join_thread
      end

      def on_start
        @logger.debug("Starting usage reporter")
        @reporting_thread.start_thread
      end
    end
  end
end
