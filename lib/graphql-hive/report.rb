# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    class Report
      def initialize(operations:, client_info: nil)
        @operations = operations
        @report = {
          size: 0,
          map: {},
          operations: []
        }
        @processed = false
        @client_info = client_info
      end

      def process_operations
        return @report if @processed

        @operations.each(&method(:add_operation_to_report))
        @processed = true
        @report
      end
      alias_method :to_json, :process_operations

      private

      def add_operation_to_report(operation)
        timestamp, queries, results, duration = operation

        errors = errors_from_results(results)

        operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(", ")
        operation = ""
        fields = Set.new

        queries.each do |query|
          analyzer = GraphQL::Hive::Analyzer.new(query)
          visitor = GraphQL::Analysis::AST::Visitor.new(
            query: query,
            analyzers: [analyzer]
          )

          result = visitor.visit

          fields.merge(analyzer.result)

          operation += "\n" unless operation.empty?
          operation += GraphQL::Hive::Printer.new.print(result)
        end

        md5 = Digest::MD5.new
        md5.update operation
        operation_map_key = md5.hexdigest

        operation_record = {
          operationMapKey: operation_map_key,
          timestamp: timestamp.to_i,
          execution: {
            ok: errors[:errorsTotal].zero?,
            duration: duration,
            errorsTotal: errors[:errorsTotal]
          }
        }

        if results[0]
          context = results[0].query.context
          operation_record[:metadata] = {client: @client_info.call(context)} if @client_info
        end

        @report[:map][operation_map_key] = {
          fields: fields.to_a,
          operationName: operation_name,
          operation: operation
        }
        @report[:operations] << operation_record
        @report[:size] += 1
      end

      def errors_from_results(results)
        acc = {errorsTotal: 0}
        results.each do |result|
          errors = result.to_h.fetch("errors", [])
          errors.each do
            acc[:errorsTotal] += 1
          end
        end
        acc
      end
    end
  end
end
