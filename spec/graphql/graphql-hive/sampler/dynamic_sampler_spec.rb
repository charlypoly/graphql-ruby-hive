# frozen_string_literal: true

require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::Sampler::DynamicSampler do
  let(:sampler_instance) { described_class.new(sampler, sampling_keygen) }
  let(:sampler) { proc { |_sample_context| 0 } }
  let(:sampling_keygen) { nil }

  let(:time) { Time.now }
  let(:queries) { [OpenStruct.new(operations: { 'getField' => {} }, query_string: 'query { field }')] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [time, queries, results, duration] }

  describe '#initialize' do
    it 'sets the sampler and tracked operations hash' do
      expect(sampler_instance.instance_variable_get(:@sampler)).to eq(sampler)
      expect(sampler_instance.instance_variable_get(:@tracked_operations)).to eq({})
    end
  end

  describe '#sample?' do
    before do
      mock_document = GraphQL::Language::Nodes::Document.new(definitions: [])
      allow(GraphQL).to receive(:parse).and_return(mock_document)
    end

    it 'follows the sampler for all operations' do
      expect(sampler_instance.sample?(operation)).to eq(false)
    end

    context 'when the sampler does not return a number' do
      let(:sampler) { proc { |_sample_context| 'not a number' } }

      it 'raises an error' do
        expect { sampler_instance.sample?(operation) }.to raise_error(StandardError, 'Error calling sampler: Sampler must return a number')
      end
    end

    context 'with at least once sampling' do
      let(:sampling_keygen) { proc { |_sample_context| 'default' } }

      it 'returns true for the first operation, then follows the sampler for remaining operations' do
        expect(sampler_instance.sample?(operation)).to eq(true)
        expect(sampler_instance.sample?(operation)).to eq(false)
      end

      context 'when provided a custom key generator' do
        let(:sampling_keygen) { proc { |_sample_context| 'same_key' } }

        it 'tracks operations by their custom keys' do
          expect(sampler_instance.sample?(operation)).to eq(true)

          queries = [OpenStruct.new(operations: { 'getDifferentField' => {} }, query_string: 'query { field }')]
          different_operation = [time, queries, results, duration]

          expect(sampler_instance.sample?(different_operation)).to eq(false)
        end
      end
    end
  end
end