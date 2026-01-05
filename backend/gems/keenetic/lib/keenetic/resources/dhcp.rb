module Keenetic
  module Resources
    # DHCP resource for managing DHCP leases and static bindings.
    #
    # == API Endpoints Used
    #
    # === Reading DHCP Leases
    #   GET /rci/show/ip/dhcp/lease
    #   Returns: Array of active DHCP leases
    #
    # === Reading Static Bindings
    #   GET /rci/show/ip/dhcp/binding
    #   Returns: Array of static IP reservations
    #
    # === Creating Static Binding
    #   POST /rci/ip/dhcp/host
    #   Body: { "mac": "AA:BB:CC:DD:EE:FF", "ip": "192.168.1.100", "name": "Server" }
    #
    # === Deleting Static Binding
    #   POST /rci/ip/dhcp/host
    #   Body: { "mac": "AA:BB:CC:DD:EE:FF", "no": true }
    #
    class DHCP < Base
      # Get all active DHCP leases.
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/dhcp/lease
      #
      # == Response Structure from API
      #   [
      #     {
      #       "ip": "192.168.1.100",
      #       "mac": "AA:BB:CC:DD:EE:FF",
      #       "hostname": "iphone",
      #       "expires": 1704067200
      #     }
      #   ]
      #
      # @return [Array<Hash>] List of normalized lease hashes
      # @example
      #   leases = client.dhcp.leases
      #   # => [{ ip: "192.168.1.100", mac: "AA:BB:CC:DD:EE:FF", hostname: "iphone", expires: 1704067200 }]
      #
      def leases
        response = get('/rci/show/ip/dhcp/lease')
        normalize_leases(response)
      end

      # Get all static DHCP bindings (IP reservations).
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/dhcp/binding
      #
      # == Response Structure from API
      #   [
      #     {
      #       "mac": "AA:BB:CC:DD:EE:FF",
      #       "ip": "192.168.1.100",
      #       "name": "My Server"
      #     }
      #   ]
      #
      # @return [Array<Hash>] List of normalized binding hashes
      # @example
      #   bindings = client.dhcp.bindings
      #   # => [{ mac: "AA:BB:CC:DD:EE:FF", ip: "192.168.1.100", name: "My Server" }]
      #
      def bindings
        response = get('/rci/show/ip/dhcp/binding')
        normalize_bindings(response)
      end

      # Find a specific binding by MAC address.
      #
      # @param mac [String] MAC address (e.g., "AA:BB:CC:DD:EE:FF")
      # @return [Hash, nil] Binding data or nil if not found
      # @example
      #   binding = client.dhcp.find_binding(mac: "AA:BB:CC:DD:EE:FF")
      #   # => { mac: "AA:BB:CC:DD:EE:FF", ip: "192.168.1.100", name: "My Server" }
      #
      def find_binding(mac:)
        normalized_mac = mac.upcase
        bindings.find { |b| b[:mac]&.upcase == normalized_mac }
      end

      # Create a static DHCP binding (IP reservation).
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"ip": {"dhcp": {"host": {"mac": "...", "ip": "...", "name": "..."}}}}]
      #
      # @param mac [String] Device MAC address
      # @param ip [String] IP address to reserve
      # @param name [String, nil] Optional friendly name for the binding
      # @return [Array<Hash>] API response
      #
      # @example Create binding with name
      #   client.dhcp.create_binding(mac: "AA:BB:CC:DD:EE:FF", ip: "192.168.1.100", name: "My Server")
      #
      # @example Create binding without name
      #   client.dhcp.create_binding(mac: "AA:BB:CC:DD:EE:FF", ip: "192.168.1.100")
      #
      def create_binding(mac:, ip:, name: nil)
        params = {
          'mac' => mac.upcase,
          'ip' => ip
        }
        params['name'] = name if name

        client.batch([{ 'ip' => { 'dhcp' => { 'host' => params } } }])
      end

      # Update an existing static DHCP binding.
      #
      # @param mac [String] Device MAC address
      # @param ip [String, nil] New IP address (optional)
      # @param name [String, nil] New name (optional)
      # @return [Array<Hash>] API response
      #
      # @example Update binding IP
      #   client.dhcp.update_binding(mac: "AA:BB:CC:DD:EE:FF", ip: "192.168.1.101")
      #
      def update_binding(mac:, ip: nil, name: nil)
        params = { 'mac' => mac.upcase }
        params['ip'] = ip if ip
        params['name'] = name if name

        return {} if params.keys == ['mac']

        client.batch([{ 'ip' => { 'dhcp' => { 'host' => params } } }])
      end

      # Delete a static DHCP binding.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"ip": {"dhcp": {"host": {"mac": "...", "no": true}}}}]
      #
      # @param mac [String] Device MAC address
      # @return [Array<Hash>] API response
      #
      # @example
      #   client.dhcp.delete_binding(mac: "AA:BB:CC:DD:EE:FF")
      #
      def delete_binding(mac:)
        client.batch([{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => mac.upcase,
                'no' => true
              }
            }
          }
        }])
      end

      private

      def normalize_leases(response)
        return [] unless response.is_a?(Array)

        response.map { |lease| normalize_lease(lease) }.compact
      end

      def normalize_lease(data)
        return nil unless data.is_a?(Hash)

        {
          ip: data['ip'],
          mac: data['mac'],
          hostname: data['hostname'],
          expires: data['expires']
        }
      end

      def normalize_bindings(response)
        return [] unless response.is_a?(Array)

        response.map { |binding| normalize_binding(binding) }.compact
      end

      def normalize_binding(data)
        return nil unless data.is_a?(Hash)

        {
          mac: data['mac'],
          ip: data['ip'],
          name: data['name']
        }
      end
    end
  end
end

