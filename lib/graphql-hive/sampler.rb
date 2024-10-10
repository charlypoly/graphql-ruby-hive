# frozen_string_literal: true

module GraphQL
  class Hive < GraphQL::Tracing::PlatformTracing
    # Sampler instance for usage reporter
    class Sampler
      def initialize(sampling_options, logger)
        # backwards compatibility with old `collect_usage_sampling` field
        if sampling_options.is_a?(Numeric)
          logger&.warn(
            "`collect_usage_sampling` is deprecated for fixed sampling rates, " \
            "use `collect_usage_sampling: { sample_rate: XX }` instead"
          )
          passed_sampling_rate = sampling_options
          sampling_options = {sample_rate: passed_sampling_rate}
        end

        sampling_options ||= {}

        @sampler = if sampling_options[:sampler]
          Sampling::DynamicSampler.new(
            sampling_options[:sampler],
            sampling_options[:at_least_once],
            sampling_options[:key_generator]
          )
        else
          Sampling::BasicSampler.new(
            sampling_options[:sample_rate],
            sampling_options[:at_least_once],
            sampling_options[:key_generator]
          )
        end
      end

      def sample?(operation)
        @sampler.sample?(operation)
      end
    end
  end
end
