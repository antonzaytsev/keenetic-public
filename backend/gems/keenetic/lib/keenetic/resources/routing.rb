module Keenetic
  module Resources
    # Routing resource for managing IP routes and ARP table.
    #
    # == API Endpoints Used
    #
    # === Reading Routing Table
    #   GET /rci/show/ip/route
    #   Returns: Array of IP routes
    #
    # === Reading ARP Table
    #   GET /rci/show/ip/arp
    #   Returns: Array of ARP entries
    #
    # === Adding Static Route
    #   POST /rci/ip/route
    #   Body: { "destination": "10.0.0.0", "mask": "255.0.0.0", "gateway": "192.168.1.1", "interface": "ISP" }
    #
    # === Deleting Static Route
    #   POST /rci/ip/route
    #   Body: { "destination": "10.0.0.0", "mask": "255.0.0.0", "no": true }
    #
    class Routing < Base
      # Get IP routing table.
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/route
      #
      # == Response Structure from API
      #   [
      #     {
      #       "destination": "0.0.0.0",
      #       "mask": "0.0.0.0",
      #       "gateway": "192.168.1.1",
      #       "interface": "ISP",
      #       "metric": 0,
      #       "flags": "G",
      #       "auto": true
      #     }
      #   ]
      #
      # @return [Array<Hash>] List of normalized route hashes
      # @example
      #   routes = client.routing.routes
      #   # => [{ destination: "0.0.0.0", mask: "0.0.0.0", gateway: "192.168.1.1", ... }]
      #
      def routes
        response = get('/rci/show/ip/route')
        normalize_routes(response)
      end

      # Get ARP table (IP to MAC address mappings).
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/arp
      #
      # == Response Structure from API
      #   [
      #     {
      #       "ip": "192.168.1.100",
      #       "mac": "AA:BB:CC:DD:EE:FF",
      #       "interface": "Bridge0",
      #       "state": "reachable"
      #     }
      #   ]
      #
      # @return [Array<Hash>] List of normalized ARP entries
      # @example
      #   arp_table = client.routing.arp_table
      #   # => [{ ip: "192.168.1.100", mac: "AA:BB:CC:DD:EE:FF", interface: "Bridge0", state: "reachable" }]
      #
      def arp_table
        response = get('/rci/show/ip/arp')
        normalize_arp_entries(response)
      end

      # Find a specific route by destination and mask.
      #
      # @param destination [String] Destination network (e.g., "10.0.0.0")
      # @param mask [String] Network mask (e.g., "255.0.0.0")
      # @return [Hash, nil] Route data or nil if not found
      # @example
      #   route = client.routing.find_route(destination: "10.0.0.0", mask: "255.0.0.0")
      #   # => { destination: "10.0.0.0", mask: "255.0.0.0", gateway: "192.168.1.1", ... }
      #
      def find_route(destination:, mask:)
        routes.find { |r| r[:destination] == destination && r[:mask] == mask }
      end

      # Find ARP entry by IP address.
      #
      # @param ip [String] IP address to look up
      # @return [Hash, nil] ARP entry or nil if not found
      # @example
      #   entry = client.routing.find_arp_entry(ip: "192.168.1.100")
      #   # => { ip: "192.168.1.100", mac: "AA:BB:CC:DD:EE:FF", ... }
      #
      def find_arp_entry(ip:)
        arp_table.find { |e| e[:ip] == ip }
      end

      # Add a static route.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"ip": {"route": {"destination": "...", "mask": "...", "gateway": "...", "interface": "..."}}}]
      #
      # @param destination [String] Destination network (e.g., "10.0.0.0")
      # @param mask [String] Network mask (e.g., "255.0.0.0")
      # @param gateway [String, nil] Next hop gateway IP address
      # @param interface [String, nil] Output interface name
      # @param metric [Integer, nil] Route metric (optional)
      # @return [Array<Hash>] API response
      #
      # @example Add route via gateway
      #   client.routing.create_route(destination: "10.0.0.0", mask: "255.0.0.0", gateway: "192.168.1.1")
      #
      # @example Add route via interface
      #   client.routing.create_route(destination: "10.0.0.0", mask: "255.0.0.0", interface: "ISP")
      #
      def create_route(destination:, mask:, gateway: nil, interface: nil, metric: nil)
        params = {
          'destination' => destination,
          'mask' => mask
        }
        params['gateway'] = gateway if gateway
        params['interface'] = interface if interface
        params['metric'] = metric if metric

        client.batch([{ 'ip' => { 'route' => params } }])
      end

      # Delete a static route.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"ip": {"route": {"destination": "...", "mask": "...", "no": true}}}]
      #
      # @param destination [String] Destination network
      # @param mask [String] Network mask
      # @return [Array<Hash>] API response
      #
      # @example
      #   client.routing.delete_route(destination: "10.0.0.0", mask: "255.0.0.0")
      #
      def delete_route(destination:, mask:)
        client.batch([{
          'ip' => {
            'route' => {
              'destination' => destination,
              'mask' => mask,
              'no' => true
            }
          }
        }])
      end

      private

      def normalize_routes(response)
        return [] unless response.is_a?(Array)

        response.map { |route| normalize_route(route) }.compact
      end

      def normalize_route(data)
        return nil unless data.is_a?(Hash)

        {
          destination: data['destination'],
          mask: data['mask'],
          gateway: data['gateway'],
          interface: data['interface'],
          metric: data['metric'],
          flags: data['flags'],
          auto: data['auto'],
          comment: data['comment']
        }
      end

      def normalize_arp_entries(response)
        return [] unless response.is_a?(Array)

        response.map { |entry| normalize_arp_entry(entry) }.compact
      end

      def normalize_arp_entry(data)
        return nil unless data.is_a?(Hash)

        {
          ip: data['ip'],
          mac: data['mac'],
          interface: data['interface'],
          state: data['state']
        }
      end
    end
  end
end

