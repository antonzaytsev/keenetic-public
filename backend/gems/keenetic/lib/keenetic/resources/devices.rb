module Keenetic
  module Resources
    # Manages network devices (hosts) connected to the router.
    #
    # == API Endpoints Used
    #
    # === Reading Devices
    #   GET /rci/show/ip/hotspot
    #   Returns: { "host": [...] } - array of registered devices
    #
    # === Writing Device Properties
    # Device updates use different RCI commands depending on the property:
    #
    # - **Name**: Set via `known.host` command
    #   POST /rci/ with [{"known":{"host":{"mac":"...","name":"..."}}}]
    #
    # - **Access Policy**: Set via `ip.hotspot.host` command
    #   POST /rci/ with [{"ip":{"hotspot":{"host":{"mac":"...","permit":true}}}}]
    #
    # - **Delete**: Remove via `ip.hotspot.host` with `no` flag
    #   POST /rci/ with [{"ip":{"hotspot":{"host":{"mac":"...","no":true}}}}]
    #
    # == MAC Address Format
    # - Reading: API returns uppercase (e.g., "AA:BB:CC:DD:EE:FF")
    # - Writing: Must use lowercase (e.g., "aa:bb:cc:dd:ee:ff")
    # - The gem handles this conversion automatically
    #
    # == Device Fields from API
    #   - mac: MAC address (uppercase, colon-separated)
    #   - name: User-assigned device name
    #   - hostname: Device-reported hostname
    #   - ip: Current IP address
    #   - interface: Connected interface ID (e.g., "Bridge0")
    #   - via: Connection path (e.g., "WifiMaster0/AccessPoint0")
    #   - active: Boolean - currently connected
    #   - registered: Boolean - registered device
    #   - access: "permit" or "deny"
    #   - schedule: Schedule name for access control
    #   - rxbytes/txbytes: Traffic counters
    #   - uptime: Current session uptime in seconds
    #   - first-seen/last-seen: Timestamps
    #
    class Devices < Base
      # Fetch all registered devices (hosts) with static IP info and Wi-Fi association data.
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/hotspot/host - device list
      #   GET /rci/show/associations - Wi-Fi client data (rssi, txrate, rxrate, mode)
      #
      # Static IP info is included in the device data as dhcp.static: true
      # When static is true, the device's ip field is the reserved static IP.
      #
      # For Wi-Fi connected devices, association data (signal strength, speed) is merged.
      #
      # @return [Array<Hash>] List of normalized device hashes with static_ip and Wi-Fi info
      # @example
      #   devices = client.devices.all
      #   # => [{ mac: "AA:BB:CC:DD:EE:FF", name: "My Phone", active: true, static_ip: "192.168.1.100", rssi: -45, ... }]
      #
      def all
        # Fetch devices and associations
        hosts_response = get('/rci/show/ip/hotspot/host')
        associations_response = get('/rci/show/associations')

        # Build MAC -> association lookup
        associations_by_mac = build_associations_lookup(associations_response || {})

        normalize_devices(hosts_response, associations_by_mac)
      end

      # Find a specific device by MAC address.
      #
      # Uses #all internally and filters by MAC (case-insensitive comparison).
      #
      # @param mac [String] Device MAC address (case-insensitive)
      # @return [Hash] Device data with static_ip info
      # @raise [NotFoundError] if device not found
      # @example
      #   device = client.devices.find(mac: 'AA:BB:CC:DD:EE:FF')
      #   # => { mac: "AA:BB:CC:DD:EE:FF", name: "My Phone", static_ip: "192.168.1.100", ... }
      #
      def find(mac:)
        devices = all
        device = devices.find { |d| d[:mac]&.downcase == mac.downcase }
        raise NotFoundError, "Device with MAC #{mac} not found" unless device
        device
      end

      # Update device properties (name, access policy, schedule).
      #
      # == Keenetic API Requests
      # Multiple commands may be sent depending on which properties are updated:
      #
      # === Setting Device Name
      #   POST /rci/ (batch format)
      #   Body: [{"known":{"host":{"mac":"aa:bb:cc:dd:ee:ff","name":"Living Room TV"}}}]
      #
      # === Setting Access Policy
      #   POST /rci/ (batch format)
      #   Body: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","permit":true}}}}]
      #   Or:   [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","deny":true}}}}]
      #
      # === Setting Schedule
      #   POST /rci/ (batch format)
      #   Body: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","schedule":"night"}}}}]
      #
      # == MAC Address
      # The MAC is automatically converted to lowercase for the API.
      #
      # @param mac [String] Device MAC address (case-insensitive)
      # @param name [String] New device name (optional)
      # @param access [String] Access policy: "permit" or "deny" (optional)
      # @param schedule [String] Schedule name for access control (optional)
      # @param policy [String, nil] Routing policy ID (e.g., "Policy0") or nil/empty to remove (optional)
      # @param static_ip [String, nil] Static IP address to reserve, or nil/empty to remove (optional)
      # @return [Array<Hash>] API response array, or {} if no attributes provided
      #
      # @example Update device name
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", name: "Living Room TV")
      #   # Sends: [{"known":{"host":{"mac":"aa:bb:cc:dd:ee:ff","name":"Living Room TV"}}}]
      #
      # @example Update access policy
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", access: "permit")
      #   # Sends: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","permit":true}}}}]
      #
      # @example Assign routing policy (VPN)
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", policy: "Policy0")
      #   # Sends: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","policy":"Policy0"}}}}]
      #
      # @example Remove routing policy (use default)
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", policy: "")
      #   # Sends: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","policy":{"no":true}}}}}]
      #
      # @example Set static IP reservation
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", static_ip: "192.168.1.100")
      #   # Sends: [{"ip":{"dhcp":{"host":{"mac":"aa:bb:cc:dd:ee:ff","ip":"192.168.1.100"}}}}]
      #
      # @example Remove static IP reservation
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", static_ip: "")
      #   # Sends: [{"ip":{"dhcp":{"host":{"mac":"aa:bb:cc:dd:ee:ff","no":true}}}}]
      #
      # @example Update multiple properties (batched in single request)
      #   client.devices.update(mac: "AA:BB:CC:DD:EE:FF", name: "TV", access: "permit")
      #   # Sends: [{"known":{"host":{...}}}, {"ip":{"hotspot":{"host":{...}}}}]
      #
      def update(mac:, **attributes)
        normalized_mac = mac.downcase
        commands = []

        # Name is set via 'known.host' RCI command
        if attributes.key?(:name)
          commands << { 'known' => { 'host' => { 'mac' => normalized_mac, 'name' => attributes[:name] } } }
        end

        # Access policy is set via 'ip.hotspot.host' RCI command
        if attributes.key?(:access) || attributes.key?(:schedule)
          hotspot_params = { 'mac' => normalized_mac }
          hotspot_params['permit'] = true if attributes[:access] == 'permit'
          hotspot_params['deny'] = true if attributes[:access] == 'deny'
          hotspot_params['schedule'] = attributes[:schedule] if attributes.key?(:schedule)
          commands << { 'ip' => { 'hotspot' => { 'host' => hotspot_params } } }
        end

        # Routing policy (VPN policy) is set via 'ip.hotspot.host.policy'
        if attributes.key?(:policy)
          policy_value = attributes[:policy]
          if policy_value.nil? || policy_value.to_s.strip.empty?
            # Remove policy assignment (use default routing)
            commands << { 'ip' => { 'hotspot' => { 'host' => { 'mac' => normalized_mac, 'policy' => { 'no' => true } } } } }
          else
            # Assign specific policy
            commands << { 'ip' => { 'hotspot' => { 'host' => { 'mac' => normalized_mac, 'policy' => policy_value } } } }
          end
        end

        # Static IP reservation is set via 'ip.dhcp.host' RCI command
        if attributes.key?(:static_ip)
          static_ip_value = attributes[:static_ip]
          if static_ip_value.nil? || static_ip_value.to_s.strip.empty?
            # Remove static IP reservation
            commands << { 'ip' => { 'dhcp' => { 'host' => { 'mac' => normalized_mac, 'no' => true } } } }
          else
            # Set static IP reservation
            commands << { 'ip' => { 'dhcp' => { 'host' => { 'mac' => normalized_mac, 'ip' => static_ip_value } } } }
          end
        end

        return {} if commands.empty?

        client.batch(commands)
      end

      # Get active (currently connected) devices only.
      #
      # Filters the result of #all to return only devices with active: true.
      #
      # @return [Array<Hash>] List of active devices
      # @example
      #   active = client.devices.active
      #   # => [{ mac: "AA:BB:CC:DD:EE:FF", name: "My Phone", active: true, ... }]
      #
      def active
        all.select { |d| d[:active] }
      end

      # Delete device registration (remove from registered list).
      #
      # == Keenetic API Request
      #   POST /rci/ (batch format)
      #   Body: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","no":true}}}}]
      #
      # The device will be unregistered but may reappear if it connects again.
      #
      # @param mac [String] Device MAC address (case-insensitive)
      # @return [Array<Hash>] API response
      # @example
      #   client.devices.delete(mac: 'AA:BB:CC:DD:EE:FF')
      #   # Sends: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","no":true}}}}]
      #
      def delete(mac:)
        client.batch([{ 'ip' => { 'hotspot' => { 'host' => { 'mac' => mac.downcase, 'no' => true } } } }])
      end

      private

      def build_associations_lookup(associations_response)
        stations = associations_response['station'] || []
        stations = [stations] unless stations.is_a?(Array)

        stations.each_with_object({}) do |station, lookup|
          next unless station.is_a?(Hash) && station['mac']

          mac = station['mac'].upcase
          lookup[mac] = {
            rssi: station['rssi'],
            txrate: station['txrate'],
            rxrate: station['rxrate'],
            mode: station['mode'],
            ht: station['ht'],
            vht: station['vht'],
            he: station['he'],
            mcs: station['mcs'],
            gi: station['gi']
          }
        end
      end

      def normalize_devices(response, associations_by_mac = {})
        return [] if response.nil?

        # Response can be an array directly or wrapped in 'host' key
        hosts = response.is_a?(Array) ? response : (response['host'] || [response])
        hosts = [hosts] unless hosts.is_a?(Array)

        hosts.map { |host| normalize_device(host, associations_by_mac) }.compact
      end

      def normalize_device(host, associations_by_mac = {})
        return nil unless host.is_a?(Hash)
        
        mac = host['mac']
        # Static IP is indicated by dhcp.static: true, and the IP is in the ip field
        dhcp_info = host['dhcp']
        is_static = dhcp_info.is_a?(Hash) && dhcp_info['static'] == true
        static_ip = is_static ? host['ip'] : nil
        
        # WiFi access point info - can be in mws.ap or ap field
        mws_info = host['mws']
        wifi_ap = mws_info.is_a?(Hash) ? mws_info['ap'] : host['ap']
        # Mesh node ID (cid) identifies which mesh node the device is connected to
        mws_cid = mws_info.is_a?(Hash) ? mws_info['cid'] : nil

        # Get Wi-Fi association data if available
        wifi_data = associations_by_mac[mac&.upcase] || {}

        {
          mac: mac,
          name: host['name'] || host['hostname'],
          hostname: host['hostname'],
          ip: host['ip'],
          static_ip: static_ip,
          interface: host['interface'],
          via: host['via'],
          wifi_ap: wifi_ap,
          mws_cid: mws_cid,
          active: host['active'] == true || host['active'] == 'true',
          registered: host['registered'] == true || host['registered'] == 'true',
          access: host['access'],
          schedule: host['schedule'],
          rxbytes: host['rxbytes'],
          txbytes: host['txbytes'],
          uptime: host['uptime'],
          first_seen: host['first-seen'],
          last_seen: host['last-seen'],
          link: host['link'],
          # Wi-Fi association data (only present for active Wi-Fi clients)
          rssi: wifi_data[:rssi],
          txrate: wifi_data[:txrate],
          rxrate: wifi_data[:rxrate],
          wifi_mode: wifi_data[:mode],
          wifi_ht: wifi_data[:ht],
          wifi_vht: wifi_data[:vht],
          wifi_he: wifi_data[:he]
        }
      end
    end
  end
end

