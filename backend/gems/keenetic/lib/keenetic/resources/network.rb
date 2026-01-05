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
    end
  end
end

