require 'time'

module Keenetic
  module Resources
    # Retrieves and filters system logs from the router.
    #
    # == API Endpoints Used
    #
    # === Reading Logs
    #   GET /rci/show/log
    #   Returns: Array of log entry objects
    #
    # === Filtered Logs (POST)
    #   POST /rci/show/log
    #   Body: { "level": "error", "limit": 100 }
    #   Returns: Filtered log entries
    #
    # == Log Entry Fields from API
    #   - time: Timestamp of the event (Unix epoch or ISO string)
    #   - level: Log level (debug, info, warning, error)
    #   - message: Human-readable log message
    #   - facility: Log facility/subsystem
    #
    # == Device Events
    # Device connection/disconnection events can be identified by:
    # - Facility: "Core::Hotspot" or "Hotspot"
    # - Keywords in message: "connected", "disconnected", "link up", "link down"
    #
    class Logs < Base
      # Device-related facilities in Keenetic logs
      DEVICE_FACILITIES = %w[
        Core::Hotspot
        Hotspot
        Core::KnownHosts
        Ndm::Hotspot
        ip::hotspot
        WifiMonitor
        Network::Interface
      ].freeze

      # Keywords indicating device connection events
      CONNECTION_KEYWORDS = [
        'connected',
        'disconnected', 
        'link up',
        'link down',
        'has connected',
        'has disconnected',
        'registered',
        'unregistered',
        'appeared',
        'disappeared',
        'joined',
        'left',
        'associated',
        'disassociated',
        'deauthenticated',
        'STA('
      ].freeze

      # Fetch all system logs.
      #
      # @param limit [Integer, nil] Maximum number of entries to return
      # @return [Array<Hash>] List of normalized log entries
      # @example
      #   logs = client.logs.all
      #   logs = client.logs.all(limit: 100)
      #
      def all(limit: nil)
        # Try batch format first (more compatible), then fall back to direct GET
        begin
          result = client.batch([{ 'show' => { 'log' => limit ? { 'limit' => limit } : {} } }])
          # Response structure: [{"show":{"log":{"log":{"123":{...},...},"continued":true}}}]
          log_data = result&.first&.dig('show', 'log')
          # The actual log entries are in the nested 'log' key
          response = log_data.is_a?(Hash) ? (log_data['log'] || log_data) : log_data
          normalize_logs(response)
        rescue StandardError
          # Fallback to direct GET
          response = get('/rci/show/log')
          normalize_logs(response)
        end
      end

      # Fetch only device connection/disconnection events.
      #
      # Filters logs to show only entries related to devices connecting
      # or disconnecting from the network.
      #
      # @param limit [Integer, nil] Maximum number of entries to fetch before filtering
      # @param mac [String, nil] Filter events for specific MAC address (optional)
      # @param since [Integer, nil] Only return events from the last N seconds (default: 3600 = 1 hour)
      # @return [Array<Hash>] List of device event log entries
      # @example
      #   events = client.logs.device_events
      #   events = client.logs.device_events(mac: 'AA:BB:CC:DD:EE:FF')
      #   events = client.logs.device_events(since: 7200) # last 2 hours
      #
      def device_events(limit: nil, mac: nil, since: 3600)
        logs = all(limit: limit)
        
        # Filter by time if since is specified
        # The logs are in router local time, so we filter based on the difference
        # between the newest log and other logs (relative filtering)
        if since && !logs.empty?
          # Find the newest log timestamp to use as reference
          newest_time = logs.map { |log| 
            next nil unless log[:time]
            begin
              Time.parse(log[:time])
            rescue ArgumentError
              nil
            end
          }.compact.max
          
          if newest_time
            cutoff_time = newest_time - since
            logs = logs.select do |log|
              next false unless log[:time]
              begin
                Time.parse(log[:time]) >= cutoff_time
              rescue ArgumentError
                true # Keep entries we can't parse
              end
            end
          end
        end
        
        events = logs.select { |log| device_connection_event?(log) }
        
        if mac
          mac_pattern = mac.upcase.gsub(':', '[:-]?')
          events = events.select { |log| log[:message]&.upcase&.match?(mac_pattern) }
        end

        # Parse device info from log messages
        events.map { |log| enrich_device_event(log) }
      end

      # Fetch logs filtered by level.
      #
      # @param level [String] Log level to filter: "debug", "info", "warning", "error"
      # @param limit [Integer, nil] Maximum entries
      # @return [Array<Hash>] Filtered log entries
      #
      def by_level(level:, limit: nil)
        params = { 'level' => level }
        params['limit'] = limit if limit
        
        result = client.batch([{ 'show' => { 'log' => params } }])
        log_data = result&.first&.dig('show', 'log')
        response = log_data.is_a?(Hash) ? (log_data['log'] || log_data) : log_data
        normalize_logs(response)
      end

      private

      def normalize_logs(response)
        return [] if response.nil?

        # Keenetic returns logs as a hash with numeric string keys: {"114154": {...}, "114155": {...}}
        # Each entry has: timestamp, ident, id, message: {level, label, message}
        logs = case response
               when Hash
                 # Sort by key (log ID) descending to get newest first
                 response.keys.sort_by { |k| k.to_i }.reverse.map { |k| response[k] }
               when Array
                 response
               else
                 []
               end

        logs.map { |log| normalize_log_entry(log) }.compact
      end

      def normalize_log_entry(entry)
        return nil unless entry.is_a?(Hash)

        # Keenetic format: { "timestamp": "Jan 7 02:20:42", "ident": "ndm", "id": 114154, 
        #                    "message": { "level": "Info", "label": "I", "message": "..." } }
        msg_obj = entry['message']
        
        if msg_obj.is_a?(Hash)
          # New Keenetic format with nested message object
          time = parse_keenetic_timestamp(entry['timestamp'])
          {
            time: time,
            level: msg_obj['level']&.downcase,
            message: msg_obj['message'],
            facility: entry['ident']
          }
        else
          # Fallback for simpler format
          time = entry['time'] || entry['timestamp']
          normalized_time = case time
                            when Integer then Time.at(time).iso8601
                            when String then time
                            else nil
                            end
          {
            time: normalized_time,
            level: (entry['level'] || entry['priority'])&.to_s&.downcase,
            message: msg_obj || entry['msg'],
            facility: entry['facility'] || entry['ident']
          }
        end
      end

      def parse_keenetic_timestamp(timestamp)
        return nil unless timestamp.is_a?(String)
        
        # Format: "Jan  7 02:20:42" - parse and add current year
        # The router may be in a different timezone, so we preserve its local time
        begin
          current_year = Time.now.year
          # Parse as UTC to avoid local timezone interference
          parsed = Time.parse("#{timestamp} #{current_year} UTC")
          # If the parsed time is more than 1 day in the future, it's probably from last year
          if parsed > Time.now.utc + 86400
            parsed = Time.parse("#{timestamp} #{current_year - 1} UTC")
          end
          # Return in ISO8601 format with the router's implied timezone
          # We mark it as UTC but it's actually the router's local time
          parsed.strftime('%Y-%m-%dT%H:%M:%S+00:00')
        rescue ArgumentError
          timestamp
        end
      end

      def device_connection_event?(log)
        return false unless log[:message]
        
        message = log[:message].downcase
        facility = log[:facility]&.to_s || ''

        # Check if facility indicates device/hotspot related
        is_device_facility = DEVICE_FACILITIES.any? { |f| facility.downcase.include?(f.downcase) }
        
        # Check if message contains connection-related keywords
        has_connection_keyword = CONNECTION_KEYWORDS.any? { |kw| message.include?(kw.downcase) }

        # Either from a device facility OR has connection keywords with MAC/IP patterns
        (is_device_facility && has_connection_keyword) || 
          (has_connection_keyword && message.match?(/([0-9a-f]{2}[:-]){5}[0-9a-f]{2}/i))
      end

      def enrich_device_event(log)
        message = log[:message] || ''
        
        # Try to extract MAC address from message
        # Keenetic uses format like STA(9c:9c:1f:44:40:a9)
        mac_match = message.match(/([0-9a-f]{2}[:-]){5}[0-9a-f]{2}/i)
        mac = mac_match ? mac_match[0].upcase.tr('-', ':') : nil

        # Try to extract IP address from message
        ip_match = message.match(/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
        ip = ip_match ? ip_match[1] : nil

        # Extract WiFi interface (2.4G or 5G band)
        interface_match = message.match(/"(WifiMaster\d+\/\w+)"/)
        interface = interface_match ? interface_match[1] : nil
        band = if interface&.include?('WifiMaster0')
                 '2.4GHz'
               elsif interface&.include?('WifiMaster1')
                 '5GHz'
               else
                 nil
               end

        # Extract reason for disconnect (if present)
        reason_match = message.match(/\(reason:\s*([^)]+)\)/i)
        reason = reason_match ? reason_match[1].strip : nil

        # Extract connection details
        details = extract_connection_details(message)

        # Determine event type
        msg_lower = message.downcase
        event_type = if msg_lower.include?('disconnected') || msg_lower.include?('left') || 
                        msg_lower.include?('disappeared') || msg_lower.include?('link down') ||
                        msg_lower.include?('disassociated') || msg_lower.include?('deauthenticated')
                       'disconnected'
                     elsif msg_lower.include?('connected') || msg_lower.include?('joined') || 
                           msg_lower.include?('appeared') || msg_lower.include?('link up') ||
                           msg_lower.include?('associated') || msg_lower.include?('set key done')
                       'connected'
                     else
                       'unknown'
                     end

        log.merge(
          mac: mac,
          ip: ip,
          event_type: event_type,
          interface: interface,
          band: band,
          reason: reason,
          details: details
        )
      end

      def extract_connection_details(message)
        details = []
        
        # WiFi security type
        if message.include?('WPA2/WPA2PSK')
          details << 'WPA2'
        elsif message.include?('WPA3')
          details << 'WPA3'
        end

        # Connection event specifics
        if message.include?('had associated')
          details << 'WiFi Associated'
        elsif message.include?('set key done')
          details << 'Authenticated'
        elsif message.include?('had deauthenticated')
          details << 'Deauthenticated'
        elsif message.include?('disassociated')
          details << 'Disassociated'
        elsif message.include?('handshake timeout')
          details << 'Handshake Timeout'
        end

        details.empty? ? nil : details.join(', ')
      end
    end
  end
end

