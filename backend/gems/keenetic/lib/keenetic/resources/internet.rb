module Keenetic
  module Resources
    class Internet < Base
      # Get internet connection status
      def status
        response = get('/rci/show/internet/status')
        normalize_status(response)
      end

      # Get current internet speed/rates
      def speed
        iface = primary_wan_interface
        return nil unless iface

        {
          interface: iface[:id],
          rxbytes: iface[:rxbytes],
          txbytes: iface[:txbytes],
          rxpackets: iface[:rxpackets],
          txpackets: iface[:txpackets],
          uptime: iface[:uptime]
        }
      end

      private

      def normalize_status(response)
        return {} unless response.is_a?(Hash)

        {
          connected: response['internet'] == true,
          gateway: response['gateway'],
          dns: normalize_dns(response['dns']),
          checked: response['checked'],
          checking: response['checking']
        }
      end

      def normalize_dns(dns)
        return [] unless dns.is_a?(Array)
        dns
      end

      def primary_wan_interface
        interfaces = client.network.interfaces
        interfaces.find { |i| i[:defaultgw] }
      end
    end
  end
end

