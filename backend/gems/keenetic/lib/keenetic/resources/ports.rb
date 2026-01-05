module Keenetic
  module Resources
    class Ports < Base
      # Get all physical port statuses
      def all
        response = get('/rci/show/interface/stat')
        normalize_ports(response)
      end

      # Get specific port by ID
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

