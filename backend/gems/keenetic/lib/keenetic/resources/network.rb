module Keenetic
  module Resources
    # Network resource for managing network interfaces.
    #
    # == API Endpoints Used
    #
    # === Reading Interfaces
    #   GET /rci/show/interface
    #   Returns: Object with interface IDs as keys, each containing interface details
    #   Example: { "GigabitEthernet0": { description, type, mac, state, ... }, "Bridge0": {...} }
    #
    # === Reading Interface Statistics
    #   GET /rci/show/interface/stat
    #   Returns: Same structure as /interface but with additional error statistics
    #   Additional fields: rxerrors, txerrors, rxdrops, txdrops, collisions, media
    #
    # === Configuring Interface
    #   POST /rci/ (batch request)
    #   Body: [{"interface": {"<interface_id>": {"up": true}}}]
    #
    # == Interface Types
    #   - GigabitEthernet: Physical Gigabit port
    #   - Bridge: Network bridge (LAN segments)
    #   - WifiMaster/AccessPoint: Wi-Fi interfaces
    #   - PPPoE, PPTP, L2TP: WAN connection types
    #   - OpenVPN, WireGuard, IPsec: VPN tunnels
    #
    class Network < Base
      # Get all network interfaces.
      #
      # == Keenetic API Request
      #   GET /rci/show/interface
      #
      # == Response Structure from API
      #   {
      #     "GigabitEthernet0": {
      #       "description": "WAN",
      #       "type": "GigabitEthernet",
      #       "mac": "AA:BB:CC:DD:EE:FF",
      #       "mtu": 1500,
      #       "state": "up",
      #       "link": "up",
      #       "connected": true,
      #       "address": "192.168.1.1",
      #       "mask": "255.255.255.0",
      #       "defaultgw": true,
      #       "rxbytes": 1000000,
      #       "txbytes": 500000,
      #       ...
      #     },
      #     "Bridge0": { ... }
      #   }
      #
      # @return [Array<Hash>] List of normalized interface hashes
      # @example
      #   interfaces = client.network.interfaces
      #   # => [{ id: "GigabitEthernet0", description: "WAN", type: "GigabitEthernet", ... }]
      #
      def interfaces
        response = get('/rci/show/interface')
        normalize_interfaces(response)
      end

      # Get specific interface by ID.
      #
      # Uses #interfaces internally to fetch all interfaces, then filters.
      #
      # @param id [String] Interface ID (e.g., "GigabitEthernet0", "Bridge0")
      # @return [Hash, nil] Interface data or nil if not found
      # @example
      #   iface = client.network.interface('Bridge0')
      #   # => { id: "Bridge0", description: "Home", type: "bridge", ... }
      #
      def interface(id)
        interfaces.find { |i| i[:id] == id }
      end

      # Get WAN interfaces (those marked as default gateway).
      #
      # @return [Array<Hash>] WAN interface(s) with defaultgw flag
      # @example
      #   wan = client.network.wan_status
      #   # => [{ id: "ISP", defaultgw: true, address: "203.0.113.50", ... }]
      #
      def wan_status
        interfaces.select { |i| i[:type] == 'wan' || i[:defaultgw] }
      end

      # Get LAN interfaces (bridges).
      #
      # @return [Array<Hash>] Bridge interfaces
      # @example
      #   lan = client.network.lan_interfaces
      #   # => [{ id: "Bridge0", description: "Home", type: "bridge", ... }]
      #
      def lan_interfaces
        interfaces.select { |i| i[:type] == 'bridge' || i[:id]&.start_with?('Bridge') }
      end

      # Get detailed interface statistics including error counts.
      #
      # == Keenetic API Request
      #   GET /rci/show/interface/stat
      #
      # == Additional Response Fields (beyond standard interface fields)
      #   - rxerrors: Receive errors count
      #   - txerrors: Transmit errors count
      #   - rxdrops: Dropped received packets
      #   - txdrops: Dropped transmitted packets
      #   - collisions: Collision count
      #   - media: Media type (e.g., "1000baseT")
      #
      # @return [Array<Hash>] List of interfaces with statistics
      # @example
      #   stats = client.network.statistics
      #   # => [{ id: "GigabitEthernet0", rxerrors: 0, txerrors: 0, rxdrops: 5, ... }]
      #
      def statistics
        response = get('/rci/show/interface/stat')
        normalize_statistics(response)
      end

      # Get statistics for a specific interface.
      #
      # Uses #statistics internally to fetch all, then filters by ID.
      #
      # @param id [String] Interface ID
      # @return [Hash, nil] Interface statistics or nil if not found
      # @example
      #   stats = client.network.interface_statistics('GigabitEthernet0')
      #   # => { id: "GigabitEthernet0", rxerrors: 0, txerrors: 0, collisions: 0, ... }
      #
      def interface_statistics(id)
        statistics.find { |i| i[:id] == id }
      end

      # Configure interface settings (enable/disable, MTU, etc.).
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format required for write operations)
      #   Body: [{"interface": {"<id>": {"up": true|false, ...}}}]
      #
      # == Common Options
      #   - up: true/false - Enable or disable the interface
      #   - mtu: Integer - Set MTU value
      #
      # @param id [String] Interface ID (e.g., "GigabitEthernet0", "WifiMaster0/AccessPoint1")
      # @param up [Boolean, nil] Enable (true) or disable (false) interface
      # @param options [Hash] Additional interface configuration options
      # @return [Array<Hash>] API response, or {} if no parameters provided
      #
      # @example Enable interface
      #   client.network.configure('GigabitEthernet0', up: true)
      #   # Sends: POST /rci/ [{"interface":{"GigabitEthernet0":{"up":true}}}]
      #
      # @example Disable Wi-Fi access point
      #   client.network.configure('WifiMaster0/AccessPoint1', up: false)
      #   # Sends: POST /rci/ [{"interface":{"WifiMaster0/AccessPoint1":{"up":false}}}]
      #
      # @example Configure with additional options
      #   client.network.configure('Bridge0', up: true, mtu: 1400)
      #
      def configure(id, up: nil, **options)
        params = options.dup
        params['up'] = up unless up.nil?

        return {} if params.empty?

        client.batch([{ 'interface' => { id => params } }])
      end

      private

      def normalize_interfaces(response)
        return [] unless response.is_a?(Hash)

        response.map { |id, data| normalize_interface(id, data) }.compact
      end

      def normalize_interface(id, data)
        return nil unless data.is_a?(Hash)

        {
          id: id,
          description: data['description'],
          type: data['type'],
          mac: data['mac'],
          mtu: data['mtu'],
          state: data['state'],
          link: data['link'],
          connected: data['connected'],
          address: data['address'],
          mask: data['mask'],
          gateway: data['gateway'],
          defaultgw: data['defaultgw'],
          uptime: data['uptime'],
          rxbytes: data['rxbytes'],
          txbytes: data['txbytes'],
          rxpackets: data['rxpackets'],
          txpackets: data['txpackets'],
          last_change: data['last-change'],
          speed: data['speed'],
          duplex: data['duplex'],
          security: data['security-level'],
          global: data['global']
        }
      end

      def normalize_statistics(response)
        return [] unless response.is_a?(Hash)

        response.map { |id, data| normalize_interface_stat(id, data) }.compact
      end

      def normalize_interface_stat(id, data)
        return nil unless data.is_a?(Hash)

        # Include all base interface fields plus statistics-specific fields
        {
          id: id,
          description: data['description'],
          type: data['type'],
          mac: data['mac'],
          mtu: data['mtu'],
          state: data['state'],
          link: data['link'],
          connected: data['connected'],
          address: data['address'],
          mask: data['mask'],
          uptime: data['uptime'],
          # Traffic counters
          rxbytes: data['rxbytes'],
          txbytes: data['txbytes'],
          rxpackets: data['rxpackets'],
          txpackets: data['txpackets'],
          # Error statistics (specific to /interface/stat)
          rxerrors: data['rxerrors'],
          txerrors: data['txerrors'],
          rxdrops: data['rxdrops'],
          txdrops: data['txdrops'],
          collisions: data['collisions'],
          media: data['media'],
          # Additional fields
          speed: data['speed'],
          duplex: data['duplex']
        }
      end
    end
  end
end

