module Keenetic
  module Resources
    class Base
      attr_reader :client

      def initialize(client)
        @client = client
      end

      protected

      def get(path, params = {})
        client.get(path, params)
      end

      def post(path, body = {})
        client.post(path, body)
      end

      # Convert kebab-case keys to snake_case symbols
      # @param hash [Hash] Hash with string keys
      # @return [Hash] Hash with symbolized snake_case keys
      def normalize_keys(hash)
        return {} unless hash.is_a?(Hash)

        hash.transform_keys { |key| key.to_s.tr('-', '_').to_sym }
      end

      # Deep normalize keys in a hash (recursive)
      # @param obj [Hash, Array, Object] Object to normalize
      # @return [Hash, Array, Object] Normalized object
      def deep_normalize_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            new_key = key.to_s.tr('-', '_').to_sym
            result[new_key] = deep_normalize_keys(value)
          end
        when Array
          obj.map { |item| deep_normalize_keys(item) }
        else
          obj
        end
      end

      # Normalize boolean values from various formats
      # API may return true/false or "true"/"false" strings
      # @param value [Object] Value to normalize
      # @return [Boolean, Object] Normalized boolean or original value
      def normalize_boolean(value)
        case value
        when true, 'true', 'yes', '1', 1
          true
        when false, 'false', 'no', '0', 0
          false
        else
          value
        end
      end

      # Normalize all boolean values in a hash
      # @param hash [Hash] Hash with potential boolean values
      # @param keys [Array<Symbol>] Keys to normalize as booleans
      # @return [Hash] Hash with normalized boolean values
      def normalize_booleans(hash, keys)
        return hash unless hash.is_a?(Hash)

        keys.each do |key|
          hash[key] = normalize_boolean(hash[key]) if hash.key?(key)
        end
        hash
      end
    end
  end
end

