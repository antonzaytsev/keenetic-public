require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Base do
  let(:client) { Keenetic::Client.new }

  # Create a test subclass to access protected methods
  let(:base_resource) do
    Class.new(described_class) do
      def test_normalize_keys(hash)
        normalize_keys(hash)
      end

      def test_deep_normalize_keys(obj)
        deep_normalize_keys(obj)
      end

      def test_normalize_boolean(value)
        normalize_boolean(value)
      end

      def test_normalize_booleans(hash, keys)
        normalize_booleans(hash, keys)
      end
    end.new(client)
  end

  before { stub_keenetic_auth }

  describe '#normalize_keys' do
    it 'converts kebab-case keys to snake_case symbols' do
      input = { 'first-name' => 'John', 'last-name' => 'Doe' }
      result = base_resource.test_normalize_keys(input)

      expect(result).to eq({ first_name: 'John', last_name: 'Doe' })
    end

    it 'handles already underscore keys' do
      input = { 'first_name' => 'John' }
      result = base_resource.test_normalize_keys(input)

      expect(result).to eq({ first_name: 'John' })
    end

    it 'handles mixed keys' do
      input = { 'kebab-case' => 1, 'snake_case' => 2, 'simple' => 3 }
      result = base_resource.test_normalize_keys(input)

      expect(result).to eq({ kebab_case: 1, snake_case: 2, simple: 3 })
    end

    it 'returns empty hash for non-hash input' do
      expect(base_resource.test_normalize_keys(nil)).to eq({})
      expect(base_resource.test_normalize_keys([])).to eq({})
      expect(base_resource.test_normalize_keys('string')).to eq({})
    end
  end

  describe '#deep_normalize_keys' do
    it 'normalizes nested hash keys' do
      input = {
        'first-level' => {
          'second-level' => {
            'third-level' => 'value'
          }
        }
      }

      result = base_resource.test_deep_normalize_keys(input)

      expect(result[:first_level][:second_level][:third_level]).to eq('value')
    end

    it 'normalizes arrays of hashes' do
      input = {
        'items' => [
          { 'item-name' => 'first', 'item-value' => 1 },
          { 'item-name' => 'second', 'item-value' => 2 }
        ]
      }

      result = base_resource.test_deep_normalize_keys(input)

      expect(result[:items]).to be_an(Array)
      expect(result[:items][0][:item_name]).to eq('first')
      expect(result[:items][1][:item_value]).to eq(2)
    end

    it 'preserves non-hash array elements' do
      input = { 'values' => [1, 'two', 3.0, true] }
      result = base_resource.test_deep_normalize_keys(input)

      expect(result[:values]).to eq([1, 'two', 3.0, true])
    end

    it 'returns non-hash/array values as-is' do
      expect(base_resource.test_deep_normalize_keys('string')).to eq('string')
      expect(base_resource.test_deep_normalize_keys(123)).to eq(123)
      expect(base_resource.test_deep_normalize_keys(nil)).to be_nil
    end
  end

  describe '#normalize_boolean' do
    context 'with truthy values' do
      it 'converts true to true' do
        expect(base_resource.test_normalize_boolean(true)).to be true
      end

      it 'converts "true" string to true' do
        expect(base_resource.test_normalize_boolean('true')).to be true
      end

      it 'converts "yes" to true' do
        expect(base_resource.test_normalize_boolean('yes')).to be true
      end

      it 'converts "1" string to true' do
        expect(base_resource.test_normalize_boolean('1')).to be true
      end

      it 'converts 1 integer to true' do
        expect(base_resource.test_normalize_boolean(1)).to be true
      end
    end

    context 'with falsy values' do
      it 'converts false to false' do
        expect(base_resource.test_normalize_boolean(false)).to be false
      end

      it 'converts "false" string to false' do
        expect(base_resource.test_normalize_boolean('false')).to be false
      end

      it 'converts "no" to false' do
        expect(base_resource.test_normalize_boolean('no')).to be false
      end

      it 'converts "0" string to false' do
        expect(base_resource.test_normalize_boolean('0')).to be false
      end

      it 'converts 0 integer to false' do
        expect(base_resource.test_normalize_boolean(0)).to be false
      end
    end

    context 'with non-boolean values' do
      it 'returns original value for unrecognized strings' do
        expect(base_resource.test_normalize_boolean('maybe')).to eq('maybe')
      end

      it 'returns original value for other types' do
        expect(base_resource.test_normalize_boolean(42)).to eq(42)
        expect(base_resource.test_normalize_boolean([])).to eq([])
        expect(base_resource.test_normalize_boolean({})).to eq({})
      end

      it 'returns nil as-is' do
        expect(base_resource.test_normalize_boolean(nil)).to be_nil
      end
    end
  end

  describe '#normalize_booleans' do
    it 'normalizes specified keys' do
      hash = { enabled: 'true', active: 'false', name: 'test' }
      result = base_resource.test_normalize_booleans(hash, %i[enabled active])

      expect(result[:enabled]).to be true
      expect(result[:active]).to be false
      expect(result[:name]).to eq('test')
    end

    it 'ignores missing keys' do
      hash = { enabled: true }
      result = base_resource.test_normalize_booleans(hash, %i[enabled missing_key])

      expect(result[:enabled]).to be true
      expect(result).not_to have_key(:missing_key)
    end

    it 'returns hash as-is for non-hash input' do
      expect(base_resource.test_normalize_booleans(nil, [:key])).to be_nil
      expect(base_resource.test_normalize_booleans([], [:key])).to eq([])
    end
  end
end

