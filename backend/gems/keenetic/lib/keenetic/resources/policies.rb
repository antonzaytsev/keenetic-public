module Keenetic
  module Resources
    # Manages routing policies (VPN policies, traffic routing rules).
    #
    # Policies allow routing specific devices through VPN tunnels or other interfaces.
    #
    # == API Endpoints Used
    #
    # === Reading Policies
    #   POST /rci/ (batch request)
    #   Body: [{"show":{"sc":{"ip":{"policy":{}}}}}]
    #
    # === Reading Device-Policy Assignments
    #   POST /rci/ (batch request)
    #   Body: [{"show":{"sc":{"ip":{"hotspot":{"host":{}}}}}}]
    #
    # == Policy Structure
    # Policies are identified by IDs like "Policy0", "Policy1", etc.
    # Each policy has:
    #   - description: Name prefixed with "!" (e.g., "!Latvia VPN")
    #   - permit: Array of interfaces this policy routes through
    #
    # == Example Response from API
    #   {
    #     "show": {
    #       "sc": {
    #         "ip": {
    #           "policy": {
    #             "Policy0": {
    #               "description": "!Latvia",
    #               "permit": [
    #                 { "interface": "Wireguard0", "enabled": true },
    #                 { "interface": "ISP", "enabled": false }
    #               ]
    #             }
    #           }
    #         }
    #       }
    #     }
    #   }
    #
    class Policies < Base
      # Fetch all routing policies.
      #
      # == Keenetic API Request
      #   POST /rci/
      #   Body: [{"show":{"sc":{"ip":{"policy":{}}}}}]
      #
      # == Response Processing
      # - Extracts policy data from nested response structure
      # - Filters permit list to only enabled interfaces (enabled: true, no: not true)
      # - Removes "!" prefix from description for clean policy name
      #
      # @return [Array<Hash>] List of policies with :id, :description, :name, :interfaces
      # @example
      #   policies = client.policies.all
      #   # => [{ id: "Policy0", description: "!Latvia", name: "Latvia",
      #   #       interfaces: ["Wireguard0"], interface_count: 1 }]
      #
      def all
        response = client.batch([
          { 'show' => { 'sc' => { 'ip' => { 'policy' => {} } } } }
        ])

        normalize_policies(response&.first)
      end

      # Get policy assignments for all devices.
      #
      # == Keenetic API Request
      #   POST /rci/
      #   Body: [{"show":{"sc":{"ip":{"hotspot":{"host":{}}}}}}]
      #
      # == Response Structure
      #   {
      #     "show": {
      #       "sc": {
      #         "ip": {
      #           "hotspot": {
      #             "host": [
      #               { "mac": "00:11:22:33:44:55", "policy": "Policy0" },
      #               { "mac": "AA:BB:CC:DD:EE:FF", "policy": "Policy1" }
      #             ]
      #           }
      #         }
      #       }
      #     }
      #   }
      #
      # @return [Hash] MAC address (lowercase) => policy ID mapping
      # @example
      #   assignments = client.policies.device_assignments
      #   # => { "00:11:22:33:44:55" => "Policy0", "aa:bb:cc:dd:ee:ff" => "Policy1" }
      #
      def device_assignments
        response = client.batch([
          { 'show' => { 'sc' => { 'ip' => { 'hotspot' => { 'host' => {} } } } } }
        ])

        extract_device_policies(response&.first)
      end

      # Find a specific policy by ID.
      #
      # @param id [String] Policy ID (e.g., "Policy0")
      # @return [Hash] Policy data
      # @raise [NotFoundError] if policy not found
      # @example
      #   policy = client.policies.find(id: 'Policy0')
      #   # => { id: "Policy0", name: "Latvia", interfaces: ["Wireguard0"], ... }
      #
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

