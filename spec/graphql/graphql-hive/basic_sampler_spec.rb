require 'spec_helper'
require 'ostruct'

RSpec.describe GraphQL::Hive::BasicSampler do
  let(:time) { Time.now }
  let(:queries) { [OpenStruct.new(operations: { 'getField' => {} }, query_string: 'query { field }')] }
  let(:results) { [OpenStruct.new(query: OpenStruct.new(context: { header: 'value' }))] }
  let(:duration) { 100 }

  let(:operation) { [time, queries, results, duration] }

  describe '#initialize' do
    it 'sets the sample rate' do
      sampler_instance = described_class.new(0.5)
      expect(sampler_instance.instance_variable_get(:@sample_rate)).to eq(0.5)
    end
  end

  describe '#sample?' do    
    it 'follows the sample rate for all operations' do
      sampler_instance = described_class.new(0)
      expect(sampler_instance.sample?(operation)).to eq(false)
    end
  end
end