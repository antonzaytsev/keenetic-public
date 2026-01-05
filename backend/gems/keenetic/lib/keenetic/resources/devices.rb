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
      # Fetch all registered devices (hosts).
      #
      # == Keenetic API Request
      #   GET /rci/show/ip/hotspot
      #
      # == Response Structure from API
      #   {
      #     "host": [
      #       {
      #         "mac": "AA:BB:CC:DD:EE:FF",
      #         "name": "My Phone",
      #         "hostname": "iphone",
      #         "ip": "192.168.1.100",
      #         "interface": "Bridge0",
      #         "via": "WifiMaster0/AccessPoint0",
      #         "active": true,
      #         "registered": true,
      #         "access": "permit",
      #         "rxbytes": 1073741824,
      #         "txbytes": 536870912,
      #         "uptime": 3600
      #       }
      #     ]
      #   }
      #
      # @return [Array<Hash>] List of normalized device hashes
      # @example
      #   devices = client.devices.all
      #   # => [{ mac: "AA:BB:CC:DD:EE:FF", name: "My Phone", active: true, ... }]
      #
      def all
        response = get('/rci/show/ip/hotspot')
        normalize_devices(response)
      end

      # Find a specific device by MAC address.
      #
      # Uses #all internally and filters by MAC (case-insensitive comparison).
      #
      # @param mac [String] Device MAC address (case-insensitive)
      # @return [Hash] Device data
      # @raise [NotFoundError] if device not found
      # @example
      #   device = client.devices.find(mac: 'AA:BB:CC:DD:EE:FF')
      #   # => { mac: "AA:BB:CC:DD:EE:FF", name: "My Phone", ... }
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

      def normalize_devices(response)
        return [] unless response.is_a?(Hash) && response['host']

        hosts = response['host']
        hosts = [hosts] unless hosts.is_a?(Array)

        hosts.map { |host| normalize_device(host) }
      end

      def normalize_device(host)
        {
          mac: host['mac'],
          name: host['name'] || host['hostname'],
          hostname: host['hostname'],
          ip: host['ip'],
          interface: host['interface'],
          via: host['via'],
          active: host['active'] == true || host['active'] == 'true',
          registered: host['registered'] == true || host['registered'] == 'true',
          access: host['access'],
          schedule: host['schedule'],
          rxbytes: host['rxbytes'],
          txbytes: host['txbytes'],
          uptime: host['uptime'],
          first_seen: host['first-seen'],
          last_seen: host['last-seen'],
          link: host['link']
        }
      end
    end
  end
end

