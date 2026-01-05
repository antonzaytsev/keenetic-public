module Keenetic
  module Resources
    class WiFi < Base
      # Get all WiFi access points
      def access_points
        response = get('/rci/show/interface')
        extract_wifi_interfaces(response)
      end

      # Get WiFi clients (connected stations)
      def clients
        response = get('/rci/show/associations')
        normalize_clients(response)
      end

      # Get specific WiFi interface
      def access_point(id)
        access_points.find { |ap| ap[:id] == id }
      end

      private

      def extract_wifi_interfaces(response)
        return [] unless response.is_a?(Hash)

        response
          .select { |id, data| wifi_interface?(data) }
          .map { |id, data| normalize_wifi(id, data) }
      end

      def wifi_interface?(data)
        return false unless data.is_a?(Hash)
        
        data['type'] == 'AccessPoint' || 
          data['id']&.start_with?('WifiMaster') ||
          data['id']&.start_with?('AccessPoint')
      end

      def normalize_wifi(id, data)
        {
          id: id,
          description: data['description'],
          type: data['type'],
          ssid: data['ssid'],
          mac: data['mac'],
          state: data['state'],
          link: data['link'],
          connected: data['connected'],
          channel: data['channel'],
          band: data['band'],
          security: data['authentication'],
          encryption: data['encryption'],
          clients_count: data['station-count'],
          txpower: data['txpower'],
          uptime: data['uptime']
        }
      end

      def normalize_clients(response)
        return [] unless response.is_a?(Hash) && response['station']

        stations = response['station']
        stations = [stations] unless stations.is_a?(Array)

        stations.map { |station| normalize_client(station) }
      end

      def normalize_client(station)
        {
          mac: station['mac'],
          ap: station['ap'],
          authenticated: station['authenticated'],
          txrate: station['txrate'],
          rxrate: station['rxrate'],
          uptime: station['uptime'],
          txbytes: station['txbytes'],
          rxbytes: station['rxbytes'],
          rssi: station['rssi'],
          mcs: station['mcs'],
          ht: station['ht'],
          mode: station['mode'],
          gi: station['gi']
        }
      end
    end
  end
end

