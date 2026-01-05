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

      # Get Mesh Wi-Fi System members (controller + extenders).
      #
      # == Keenetic API Request
      #   POST /rci/
      #   Body: [{"show":{"mws":{"member":{}}}}, {"show":{"mws":{"status":{}}}}]
      #
      # == Response Structure from API
      #   Member data includes:
      #     - known: true/false (if node is registered)
      #     - online: true/false
      #     - cid: unique controller ID
      #     - mac: device MAC address
      #     - hw-id: hardware ID
      #     - hw-version: hardware version
      #     - model: device model (e.g., "KN-4010", "KN-1613")
      #     - name: device name
      #     - mode: operating mode ("controller", "extender")
      #     - via: connection path (e.g., "Ethernet", "WifiMaster1")
      #     - ip: device IP address
      #     - uptime: uptime in seconds
      #     - version: firmware version
      #
      # @return [Array<Hash>] List of mesh nodes (controller + extenders)
      # @example
      #   nodes = client.wifi.mesh_members
      #   # => [{ id: "abc123", name: "Main Router", mode: "controller", ... }]
      #
      def mesh_members
        responses = client.batch([
          { 'show' => { 'mws' => { 'member' => {} } } },
          { 'show' => { 'version' => {} } },
          { 'show' => { 'system' => {} } },
          { 'show' => { 'associations' => {} } }
        ])
        
        members_response = responses[0] || {}
        version_response = responses[1] || {}
        system_response = responses[2] || {}
        associations_response = responses[3] || {}
        
        # Get extenders from mws member
        extenders = normalize_mesh_members(members_response)
        
        # Build controller from version/system info
        controller = build_controller(version_response, system_response, associations_response)
        
        # Return controller first, then extenders
        [controller, *extenders].compact
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

      # Configure Wi-Fi access point settings.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"interface": {"<ap_id>": {<config>}}}]
      #
      # == Authentication Types
      #   - "open": No security
      #   - "wpa-psk": WPA Personal
      #   - "wpa2-psk": WPA2 Personal
      #   - "wpa3-psk": WPA3 Personal
      #   - "wpa2/wpa3-psk": WPA2/WPA3 mixed mode
      #
      # == Encryption Types
      #   - "aes": AES encryption (recommended)
      #   - "tkip": TKIP encryption (legacy)
      #
      # @param id [String] Access point ID (e.g., "WifiMaster0/AccessPoint0")
      # @param options [Hash] Configuration options
      # @option options [String] :ssid Network name
      # @option options [String] :authentication Security mode
      # @option options [String] :encryption Encryption type
      # @option options [String] :key Wi-Fi password
      # @option options [Integer] :channel Channel number (0 for auto)
      # @option options [Boolean] :up Enable or disable the access point
      # @return [Array<Hash>] API response
      #
      # @example Configure access point
      #   client.wifi.configure('WifiMaster0/AccessPoint0',
      #     ssid: 'MyNetwork',
      #     authentication: 'wpa2-psk',
      #     encryption: 'aes',
      #     key: 'mysecretpassword',
      #     up: true
      #   )
      #   # Sends: [{"interface":{"WifiMaster0/AccessPoint0":{"ssid":"MyNetwork",...}}}]
      #
      # @example Change SSID only
      #   client.wifi.configure('WifiMaster0/AccessPoint0', ssid: 'NewNetworkName')
      #
      # @example Set channel
      #   client.wifi.configure('WifiMaster0', channel: 6)
      #
      def configure(id, **options)
        params = {}

        params['ssid'] = options[:ssid] if options[:ssid]
        params['authentication'] = options[:authentication] if options[:authentication]
        params['encryption'] = options[:encryption] if options[:encryption]
        params['key'] = options[:key] if options[:key]
        params['channel'] = options[:channel] if options[:channel]
        params['up'] = options[:up] unless options[:up].nil?

        return {} if params.empty?

        client.batch([{ 'interface' => { id => params } }])
      end

      # Enable a Wi-Fi access point.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"interface": {"<ap_id>": {"up": true}}}]
      #
      # @param id [String] Access point ID (e.g., "WifiMaster0/AccessPoint0")
      # @return [Array<Hash>] API response
      #
      # @example Enable access point
      #   client.wifi.enable('WifiMaster0/AccessPoint0')
      #   # Sends: [{"interface":{"WifiMaster0/AccessPoint0":{"up":true}}}]
      #
      def enable(id)
        client.batch([{ 'interface' => { id => { 'up' => true } } }])
      end

      # Disable a Wi-Fi access point.
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"interface": {"<ap_id>": {"up": false}}}]
      #
      # @param id [String] Access point ID (e.g., "WifiMaster0/AccessPoint0")
      # @return [Array<Hash>] API response
      #
      # @example Disable guest network
      #   client.wifi.disable('WifiMaster0/AccessPoint1')
      #   # Sends: [{"interface":{"WifiMaster0/AccessPoint1":{"up":false}}}]
      #
      def disable(id)
        client.batch([{ 'interface' => { id => { 'up' => false } } }])
      end

      private

      def extract_wifi_interfaces(response)
        return [] unless response.is_a?(Hash)

        response
          .select { |id, data| wifi_interface?(id, data) }
          .map { |id, data| normalize_wifi(id, data) }
      end

      def wifi_interface?(id, data)
        return false unless data.is_a?(Hash)
        
        data['type'] == 'AccessPoint' || 
          data['type'] == 'WifiMaster' ||
          id.start_with?('WifiMaster') ||
          id.start_with?('AccessPoint')
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

      def normalize_mesh_members(members_response)
        # Response is nested: { "show" => { "mws" => { "member" => [...] } } }
        members_data = members_response.dig('show', 'mws', 'member') if members_response.is_a?(Hash)
        return [] unless members_data

        members = members_data.is_a?(Array) ? members_data : [members_data]
        
        members.filter_map { |member| normalize_mesh_member(member) }
      end

      def build_controller(version_response, system_response, associations_response)
        version = version_response.dig('show', 'version') || {}
        system = system_response.dig('show', 'system') || {}
        
        # Count associations (wifi clients connected to controller)
        stations = associations_response.dig('show', 'associations', 'station') || []
        stations = [stations] unless stations.is_a?(Array)
        client_count = stations.size
        
        return nil if version.empty?
        
        {
          id: 'controller',
          mac: version['mac'],
          name: system['name'] || version['description'] || version['model'],
          model: "#{version['model']} (#{version['hw_id']})",
          hw_id: version['hw_id'],
          hw_version: version['hw_version'],
          mode: 'controller',
          via: nil, # Controller doesn't have upstream
          ip: nil, # Controller is the gateway
          version: version['release'],
          online: true,
          uptime: system['uptime'],
          clients_count: client_count,
          connection_speed: nil,
          alert: false
        }
      end

      def normalize_mesh_member(member)
        return nil unless member.is_a?(Hash)

        cid = member['cid']
        system_info = member['system'] || {}
        backhaul_info = member['backhaul'] || {}
        
        {
          id: cid,
          mac: member['mac'],
          name: member['known-host'] || member['model'],
          model: member['model'],
          hw_id: member['hw_id'] || member['hw-id'],
          hw_version: member['hw-version'],
          mode: member['mode'], # "controller" or "extender"
          via: backhaul_info['uplink'], # Connection method (FastEthernet0/Vlan1, WifiMaster1, etc.)
          ip: member['ip'],
          version: member['fw'],
          online: true, # Members in the list are online
          uptime: system_info['uptime']&.to_i,
          clients_count: member['associations'],
          connection_speed: backhaul_info['speed'],
          alert: false
        }
      end
    end
  end
end

