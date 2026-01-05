module Keenetic
  module Resources
    # Wi-Fi resource for accessing wireless network information.
    #
    # == API Endpoints Used
    #
    # === Reading Wi-Fi Access Points
    #   GET /rci/show/interface
    #   Filters: interfaces where type == "AccessPoint" or id starts with "WifiMaster"
    #   Returns Wi-Fi specific fields: ssid, channel, band, authentication, encryption, station-count
    #
    # === Reading Connected Clients (Associations)
    #   GET /rci/show/associations
    #   Returns: { "station": [...] } - array of connected Wi-Fi clients
    #   Station fields: mac, ap, rssi, txrate, rxrate, uptime, ht/vht/he mode flags
    #
    # == Wi-Fi Interface Naming
    #   - WifiMaster0: First Wi-Fi radio (usually 2.4GHz)
    #   - WifiMaster1: Second Wi-Fi radio (usually 5GHz)
    #   - WifiMaster0/AccessPoint0: Main SSID on first radio
    #   - WifiMaster0/AccessPoint1: Guest SSID on first radio
    #
    class WiFi < Base
      # Get all Wi-Fi access points.
      #
      # == Keenetic API Request
      #   GET /rci/show/interface
      #   Internally filters for Wi-Fi interfaces only
      #
      # == Wi-Fi Specific Fields from API
      #   - ssid: Network name
      #   - channel: Wi-Fi channel number
      #   - band: Frequency band ("2.4GHz", "5GHz")
      #   - authentication: Security mode (wpa2-psk, wpa3-psk, etc.)
      #   - encryption: Encryption type (aes, tkip)
      #   - station-count: Number of connected clients
      #   - txpower: Transmit power in dBm
      #
      # @return [Array<Hash>] List of Wi-Fi access points
      # @example
      #   aps = client.wifi.access_points
      #   # => [{ id: "WifiMaster0/AccessPoint0", ssid: "MyNetwork", channel: 6, band: "2.4GHz", ... }]
      #
      def access_points
        response = get('/rci/show/interface')
        extract_wifi_interfaces(response)
      end

      # Get connected Wi-Fi clients (associations).
      #
      # == Keenetic API Request
      #   GET /rci/show/associations
      #
      # == Response Structure from API
      #   {
      #     "station": [
      #       {
      #         "mac": "AA:BB:CC:DD:EE:FF",
      #         "ap": "WifiMaster0/AccessPoint0",
      #         "authenticated": true,
      #         "txrate": 866700,
      #         "rxrate": 780000,
      #         "rssi": -45,
      #         "uptime": 3600,
      #         "mcs": 9,
      #         "ht": false,
      #         "vht": true,
      #         "mode": "ac",
      #         "gi": "short"
      #       }
      #     ]
      #   }
      #
      # == Signal Strength (RSSI)
      #   - rssi: Signal strength in dBm (negative value, closer to 0 is stronger)
      #   - Typical ranges: -30 to -50 (excellent), -50 to -70 (good), -70 to -80 (fair)
      #
      # @return [Array<Hash>] List of connected Wi-Fi clients
      # @example
      #   clients = client.wifi.clients
      #   # => [{ mac: "AA:BB:CC:DD:EE:FF", ap: "WifiMaster0/AccessPoint0", rssi: -45, ... }]
      #
      def clients
        response = get('/rci/show/associations')
        normalize_clients(response)
      end

      # Get specific Wi-Fi access point by ID.
      #
      # @param id [String] Access point ID (e.g., "WifiMaster0/AccessPoint0")
      # @return [Hash, nil] Access point data or nil if not found
      # @example
      #   ap = client.wifi.access_point('WifiMaster0/AccessPoint0')
      #   # => { id: "WifiMaster0/AccessPoint0", ssid: "MyNetwork", ... }
      #
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

