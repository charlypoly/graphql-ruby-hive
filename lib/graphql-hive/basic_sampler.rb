module GraphQL
  class Hive
    # Basic sampling for operations reporting
    class BasicSampler
      def initialize(client_sample_rate)
        @sample_rate = client_sample_rate
      end

      def sample?(operation)
        SecureRandom.random_number <= @sample_rate
      end
    end
  end
end