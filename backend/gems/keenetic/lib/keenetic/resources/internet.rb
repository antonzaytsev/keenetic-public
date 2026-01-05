module Keenetic
  module Resources
    # Internet resource for checking WAN connectivity status.
    #
    # == API Endpoints Used
    #
    # === Reading Internet Status
    #   GET /rci/show/internet/status
    #   Returns: { internet, gateway, dns, checked, checking, interface, address }
    #
    # === Reading Speed/Traffic (via Network interfaces)
    #   Uses client.network.interfaces internally to get WAN interface statistics
    #   Filters for interface with defaultgw flag
    #
    class Internet < Base
      # Get internet connection status.
      #
      # == Keenetic API Request
      #   GET /rci/show/internet/status
      #
      # == Response Fields from API
      #   - internet: Boolean - true if internet is reachable
      #   - gateway: Default gateway IP address
      #   - dns: Array of DNS server addresses
      #   - checked: Timestamp of last connectivity check
      #   - checking: Boolean - check currently in progress
      #   - interface: Active WAN interface name
      #   - address: WAN IP address
      #
      # @return [Hash] Internet status with :connected, :gateway, :dns, :checked, :checking
      # @example
      #   status = client.internet.status
      #   # => { connected: true, gateway: "10.0.0.1", dns: ["8.8.8.8", "8.8.4.4"], ... }
      #
      def status
        response = get('/rci/show/internet/status')
        normalize_status(response)
      end

      # Get current WAN traffic statistics.
      #
      # Uses the primary WAN interface (with defaultgw flag) from network.interfaces.
      #
      # == How It Works
      #   1. Fetches all interfaces via client.network.interfaces
      #   2. Finds interface with :defaultgw flag
      #   3. Returns traffic counters from that interface
      #
      # @return [Hash, nil] WAN traffic stats or nil if no WAN interface found
      # @example
      #   speed = client.internet.speed
      #   # => { interface: "ISP", rxbytes: 1073741824, txbytes: 536870912, uptime: 86400 }
      #
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

