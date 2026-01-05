module Keenetic
  module Resources
    class Devices < Base
      # Fetch all registered devices (hosts)
      def all
        response = get('/rci/show/ip/hotspot')
        normalize_devices(response)
      end

      # Find a specific device by MAC address
      def find(mac:)
        devices = all
        device = devices.find { |d| d[:mac]&.downcase == mac.downcase }
        raise NotFoundError, "Device with MAC #{mac} not found" unless device
        device
      end

      # Update device properties (name, access policy, etc.)
      def update(mac:, **attributes)
        body = { mac: mac.upcase }
        body[:name] = attributes[:name] if attributes.key?(:name)
        body[:access] = attributes[:access] if attributes.key?(:access)
        body[:schedule] = attributes[:schedule] if attributes.key?(:schedule)
        
        post('/rci/ip/hotspot/host', body)
      end

      # Get active (currently connected) devices only
      def active
        all.select { |d| d[:active] }
      end

      # Delete device registration (remove from registered list)
      # @param mac [String] Device MAC address
      # @return [Hash] API response
      def delete(mac:)
        post('/rci/ip/hotspot/host', { mac: mac.upcase, no: true })
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

