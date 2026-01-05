module Keenetic
  module Resources
    # Manages network devices (hosts) connected to the router.
    #
    # == Reading Devices
    #   GET /rci/show/ip/hotspot - returns all registered devices
    #
    # == Writing Device Properties
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
    # All write operations require lowercase MAC addresses (e.g., "aa:bb:cc:dd:ee:ff")
    #
    class Devices < Base
      # Fetch all registered devices (hosts)
      # @return [Array<Hash>] List of normalized device hashes
      def all
        response = get('/rci/show/ip/hotspot')
        normalize_devices(response)
      end

      # Find a specific device by MAC address
      # @param mac [String] Device MAC address (case-insensitive)
      # @return [Hash] Device data
      # @raise [NotFoundError] if device not found
      def find(mac:)
        devices = all
        device = devices.find { |d| d[:mac]&.downcase == mac.downcase }
        raise NotFoundError, "Device with MAC #{mac} not found" unless device
        device
      end

      # Update device properties (name, access policy, schedule)
      #
      # @param mac [String] Device MAC address
      # @param name [String] New device name (optional)
      # @param access [String] Access policy: "permit" or "deny" (optional)
      # @param schedule [String] Schedule name for access control (optional)
      # @return [Array<Hash>] API response array
      #
      # @example Update device name
      #   client.devices.update(mac: "aa:bb:cc:dd:ee:ff", name: "Living Room TV")
      #
      # @example Update access policy
      #   client.devices.update(mac: "aa:bb:cc:dd:ee:ff", access: "permit")
      #
      # @example Update multiple properties
      #   client.devices.update(mac: "aa:bb:cc:dd:ee:ff", name: "TV", access: "permit")
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

      # Get active (currently connected) devices only
      # @return [Array<Hash>] List of active devices
      def active
        all.select { |d| d[:active] }
      end

      # Delete device registration (remove from registered list)
      # @param mac [String] Device MAC address
      # @return [Array<Hash>] API response
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

