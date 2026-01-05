module Keenetic
  module Resources
    # Ports resource for accessing physical Ethernet port status.
    #
    # == API Endpoints Used
    #
    # === Reading Port Statistics
    #   GET /rci/show/interface/stat
    #   Filters: Physical ports only (GigabitEthernet*, FastEthernet*, SFP*, USB*)
    #
    # == Port Naming Convention
    #   - GigabitEthernet0, GigabitEthernet1, etc.: Gigabit Ethernet ports
    #   - FastEthernet0, etc.: Fast Ethernet ports (100Mbps)
    #   - SFP0: SFP port (if available)
    #
    # == Link Status
    #   - link: true = cable connected, false = no cable
    #   - speed: Current negotiated speed (1000, 100, 10 Mbps)
    #   - duplex: "full" or "half"
    #
    class Ports < Base
      # Get all physical port statuses.
      #
      # == Keenetic API Request
      #   GET /rci/show/interface/stat
      #   Internally filters for physical ports only
      #
      # == Response Fields
      #   - id: Interface ID (e.g., "GigabitEthernet0")
      #   - port: Port number extracted from ID
      #   - type: "gigabit", "fast", "sfp", or "usb"
      #   - link: true if cable connected
      #   - speed: Negotiated speed in Mbps
      #   - duplex: "full" or "half"
      #   - rxbytes/txbytes: Traffic counters
      #   - rxerrors/txerrors: Error counters
      #   - media: Media type string
      #
      # @return [Array<Hash>] List of physical ports with status
      # @example
      #   ports = client.ports.all
      #   # => [{ id: "GigabitEthernet0", port: 0, type: "gigabit", link: true, speed: 1000, ... }]
      #
      def all
        response = get('/rci/show/interface/stat')
        normalize_ports(response)
      end

      # Get specific port by ID.
      #
      # @param id [String] Port interface ID (e.g., "GigabitEthernet0")
      # @return [Hash, nil] Port data or nil if not found
      # @example
      #   port = client.ports.find('GigabitEthernet0')
      #   # => { id: "GigabitEthernet0", port: 0, link: true, speed: 1000, ... }
      #
      def find(id)
        all.find { |p| p[:id] == id }
      end

      private

      def normalize_ports(response)
        return [] unless response.is_a?(Hash)

        response.filter_map do |id, data|
          next unless physical_port?(id, data)
          normalize_port(id, data)
        end
      end

      def physical_port?(id, data)
        return false unless data.is_a?(Hash)
        
        # Physical ports are typically named GigabitEthernet0, GigabitEthernet1, etc.
        # or SFP ports, or USB ports
        id.match?(/^(Gigabit|Fast)?Ethernet\d+|SFP|USB/)
      end

      def normalize_port(id, data)
        {
          id: id,
          port: extract_port_number(id),
          type: extract_port_type(id),
          link: data['link'] == true,
          speed: data['speed'],
          duplex: data['duplex'],
          rxbytes: data['rxbytes'],
          txbytes: data['txbytes'],
          rxpackets: data['rxpackets'],
          txpackets: data['txpackets'],
          rxerrors: data['rxerrors'],
          txerrors: data['txerrors'],
          media: data['media']
        }
      end

      def extract_port_number(id)
        match = id.match(/(\d+)$/)
        match ? match[1].to_i : nil
      end

      def extract_port_type(id)
        case id
        when /GigabitEthernet/ then 'gigabit'
        when /FastEthernet/ then 'fast'
        when /SFP/ then 'sfp'
        when /USB/ then 'usb'
        else 'unknown'
        end
      end
    end
  end
end

