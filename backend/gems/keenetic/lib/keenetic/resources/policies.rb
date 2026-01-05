module Keenetic
  module Resources
    # Manages routing policies (VPN policies, traffic routing rules).
    #
    # Policies allow routing specific devices through VPN tunnels or other interfaces.
    #
    # == Reading Policies
    #   - IP Policies: GET via batch [{"show":{"sc":{"ip":{"policy":{}}}}}]
    #   - Hotspot Policies: GET via batch [{"show":{"sc":{"ip":{"hotspot":{"policy":{}}}}}}]
    #   - Device-Policy assignments: GET via batch [{"show":{"sc":{"ip":{"hotspot":{"host":{}}}}}}]
    #
    class Policies < Base
      # Fetch all routing policies with their descriptions
      # @return [Array<Hash>] List of policies with id, description, and interfaces
      def all
        response = client.batch([
          { 'show' => { 'sc' => { 'ip' => { 'policy' => {} } } } }
        ])

        normalize_policies(response&.first)
      end

      # Get policy assignments for all devices
      # @return [Hash] MAC address => policy name mapping
      def device_assignments
        response = client.batch([
          { 'show' => { 'sc' => { 'ip' => { 'hotspot' => { 'host' => {} } } } } }
        ])

        extract_device_policies(response&.first)
      end

      # Find a specific policy by ID
      # @param id [String] Policy ID (e.g., "Policy0")
      # @return [Hash] Policy data
      # @raise [NotFoundError] if policy not found
      def find(id:)
        policies = all
        policy = policies.find { |p| p[:id] == id }
        raise NotFoundError, "Policy #{id} not found" unless policy
        policy
      end

      private

      def normalize_policies(response)
        return [] unless response.is_a?(Hash)

        policies_data = response.dig('show', 'sc', 'ip', 'policy')
        return [] unless policies_data.is_a?(Hash)

        policies_data.map do |id, data|
          normalize_policy(id, data)
        end
      end

      def normalize_policy(id, data)
        return nil unless data.is_a?(Hash)

        # Extract active interfaces from permit list
        permits = data['permit'] || []
        active_interfaces = permits
          .select { |p| p.is_a?(Hash) && p['enabled'] == true && p['no'] != true }
          .map { |p| p['interface'] }
          .compact

        {
          id: id,
          description: data['description'] || id,
          name: extract_policy_name(data['description'] || id),
          interfaces: active_interfaces,
          interface_count: active_interfaces.size
        }
      end

      def extract_policy_name(description)
        # Remove leading "!" and clean up the name
        name = description.to_s.sub(/^!/, '').strip
        name.empty? ? 'Unnamed Policy' : name
      end

      def extract_device_policies(response)
        return {} unless response.is_a?(Hash)

        hosts = response.dig('show', 'sc', 'ip', 'hotspot', 'host')
        return {} unless hosts.is_a?(Array)

        hosts.each_with_object({}) do |host, mapping|
          next unless host.is_a?(Hash) && host['policy']
          mapping[host['mac']&.downcase] = host['policy']
        end
      end
    end
  end
end

