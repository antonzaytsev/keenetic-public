module Keenetic
  module Resources
    class Network < Base
      # Get all network interfaces
      def interfaces
        response = get('/rci/show/interface')
        normalize_interfaces(response)
      end

      # Get specific interface by ID
      def interface(id)
        interfaces.find { |i| i[:id] == id }
      end

      # Get WAN interface status
      def wan_status
        interfaces.select { |i| i[:type] == 'wan' || i[:defaultgw] }
      end

      # Get LAN interfaces
      def lan_interfaces
        interfaces.select { |i| i[:type] == 'bridge' || i[:id]&.start_with?('Bridge') }
      end

      # Get detailed interface statistics including error counts
      # @return [Array<Hash>] List of interfaces with statistics
      def statistics
        response = get('/rci/show/interface/stat')
        normalize_statistics(response)
      end

      # Get statistics for a specific interface
      # @param id [String] Interface ID
      # @return [Hash, nil] Interface statistics or nil if not found
      def interface_statistics(id)
        statistics.find { |i| i[:id] == id }
      end

      # Configure interface settings
      # @param id [String] Interface ID
      # @param up [Boolean, nil] Enable (true) or disable (false) interface
      # @param options [Hash] Additional interface configuration options
      # @return [Array<Hash>] API response
      #
      # @example Enable interface
      #   client.network.configure('GigabitEthernet0', up: true)
      #
      # @example Disable interface
      #   client.network.configure('WifiMaster0/AccessPoint1', up: false)
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

