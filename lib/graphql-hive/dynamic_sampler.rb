module GraphQL
  class Hive
    # Dynamic sampling for operations reporting
    class DynamicSampler
      def initialize(client_sampler, sample_key_generator = default_sample_key)
        @sampler = client_sampler
        @tracked_operations = Hash.new
        @sample_key_generator = sample_key_generator
      end

      def sample?(operation)
        sample_context = get_sample_context(operation)

        sample_rate = get_sample_rate(sample_context)
        operation_key = get_sample_key(sample_context)

        if (@tracked_operations.has_key?(operation_key))
          @sample_rate = sample_rate
        else
          @tracked_operations[operation_key] = true 
          return true
        end

        SecureRandom.random_number <= @sample_rate
      end

      private

      def get_sample_context(operation) 
        _, queries, results, _ = operation

        operation_name = queries.map(&:operations).map(&:keys).flatten.compact.join(', ')

        parsed_definitions = []
        queries.each do |query|
          parsed_query = GraphQL::Language::Parser.parse(query.query_string)
          parsed_definitions.concat(parsed_query.definitions)
        end
        document = GraphQL::Language::Nodes::Document.new(definitions: parsed_definitions)

        context_value = results[0].query.context

        {
          operation_name: operation_name,
          document: document,
          context_value: context_value
        }
      end

      def get_sample_rate(sample_context)
        sample_rate = @sampler.call(sample_context)
        raise StandardError, "DynamicSampler must return a number" unless (sample_rate.is_a?(Numeric))
        sample_rate
      rescue => e
        raise StandardError, "Error calling sampler: #{e}"
      end

      def get_sample_key(sample_context)
        @sample_key_generator.call(sample_context).to_s
      rescue => e
        raise StandardError, "Error getting key for sample: #{e}"
      end

      def default_sample_key
        Proc.new { |sample_context| sample_context[:operation_name] + sample_context[:document].to_query_string }
      end
    end
  end
end