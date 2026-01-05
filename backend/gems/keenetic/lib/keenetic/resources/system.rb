module Keenetic
  module Resources
    # System resource for accessing router system information and status.
    #
    # == API Endpoints Used
    #
    # === Reading System Status
    #   GET /rci/show/system
    #   Returns: { cpuload, memtotal, memfree, membuffers, memcache, swaptotal, swapfree, uptime }
    #
    # === Reading System Info
    #   GET /rci/show/version
    #   Returns: { model, device, manufacturer, hw_version, release, ndm, ndw, ... }
    #
    # === Reading Defaults
    #   GET /rci/show/defaults
    #   Returns: Default configuration values (system-name, domain-name, etc.)
    #
    # === Reading License
    #   GET /rci/show/license
    #   Returns: { valid, active, expires, type, features, services }
    #
    class System < Base
      # Get system resource usage (CPU, memory, swap).
      #
      # == Keenetic API Request
      #   GET /rci/show/system
      #
      # == Response Fields from API
      #   - cpuload: CPU usage percentage (0-100)
      #   - memtotal: Total RAM in bytes
      #   - memfree: Free RAM in bytes
      #   - membuffers: Buffer memory in bytes
      #   - memcache: Cached memory in bytes
      #   - swaptotal: Total swap in bytes
      #   - swapfree: Free swap in bytes
      #   - uptime: System uptime in seconds
      #
      # @return [Hash] Normalized resource data with :cpu, :memory, :swap, :uptime
      # @example
      #   resources = client.system.resources
      #   # => { cpu: { load_percent: 15 },
      #   #      memory: { total: 536870912, free: 268435456, used: 215789568, used_percent: 40.2 },
      #   #      swap: { total: 0, free: 0, used: 0, used_percent: 0 },
      #   #      uptime: 86400 }
      #
      def resources
        response = get('/rci/show/system')
        normalize_resources(response)
      end

      # Get router system information (model, firmware, hardware).
      #
      # == Keenetic API Request
      #   GET /rci/show/version
      #
      # == Response Fields from API
      #   - model: Router model name (e.g., "Keenetic Viva")
      #   - device: Device code (e.g., "KN-1912")
      #   - manufacturer: "Keenetic Ltd."
      #   - vendor: "Keenetic"
      #   - hw_version: Hardware revision
      #   - title: Firmware title
      #   - release: Firmware version string
      #   - ndm: { version, exact } - NDM version info
      #   - ndw: { version } - NDW version info
      #   - arch: CPU architecture (e.g., "mips", "aarch64")
      #   - components: Array of installed components
      #
      # @return [Hash] Normalized system info
      # @example
      #   info = client.system.info
      #   # => { model: "Keenetic Viva", device: "KN-1912", firmware_version: "4.01.C.7.0-0", ... }
      #
      def info
        response = get('/rci/show/version')
        normalize_info(response)
      end

      # Get system uptime in seconds.
      #
      # == Keenetic API Request
      #   GET /rci/show/system
      #
      # @return [Integer] Uptime in seconds
      # @example
      #   client.system.uptime
      #   # => 86400  (1 day)
      #
      def uptime
        response = get('/rci/show/system')
        response['uptime'] if response.is_a?(Hash)
      end

      # Get default system configuration values.
      #
      # == Keenetic API Request
      #   GET /rci/show/defaults
      #
      # == Response Fields from API (examples)
      #   - system-name: Default router name
      #   - domain-name: Default domain
      #   - language: System language
      #   - ntp-server: Default NTP server
      #
      # @return [Hash] Default configuration with snake_case keys
      # @example
      #   defaults = client.system.defaults
      #   # => { system_name: "Keenetic", domain_name: "local", language: "en", ... }
      #
      def defaults
        response = get('/rci/show/defaults')
        normalize_defaults(response)
      end

      # Get license status and enabled features.
      #
      # == Keenetic API Request
      #   GET /rci/show/license
      #
      # == Response Fields from API
      #   - valid: Boolean - license is valid
      #   - active: Boolean - license is active
      #   - expires: Expiration date string
      #   - type: License type (e.g., "standard")
      #   - features: Array of enabled features
      #   - services: Array of service statuses
      #
      # @return [Hash] License information
      # @example
      #   license = client.system.license
      #   # => { valid: true, active: true, expires: "2025-12-31",
      #   #      features: [{ name: "vpn-server", enabled: true }],
      #   #      services: [{ name: "keendns", enabled: true, active: true }] }
      #
      def license
        response = get('/rci/show/license')
        normalize_license(response)
      end

      private

      def normalize_resources(response)
        return {} unless response.is_a?(Hash)

        {
          cpu: normalize_cpu(response['cpuload']),
          memory: normalize_memory(response),
          swap: normalize_swap(response),
          uptime: response['uptime']
        }
      end

      def normalize_cpu(cpuload)
        return nil unless cpuload

        {
          load_percent: cpuload.to_i
        }
      end

      def normalize_memory(response)
        total = response['memtotal']
        free = response['memfree']
        buffers = response['membuffers'] || 0
        cached = response['memcache'] || 0

        return nil unless total && free

        used = total - free - buffers - cached
        
        {
          total: total,
          free: free,
          used: used,
          buffers: buffers,
          cached: cached,
          used_percent: ((used.to_f / total) * 100).round(1)
        }
      end

      def normalize_swap(response)
        total = response['swaptotal']
        free = response['swapfree']

        return nil unless total && free && total > 0

        used = total - free
        
        {
          total: total,
          free: free,
          used: used,
          used_percent: ((used.to_f / total) * 100).round(1)
        }
      end

      def normalize_info(response)
        return {} unless response.is_a?(Hash)

        {
          model: response['model'],
          device: response['device'],
          manufacturer: response['manufacturer'],
          vendor: response['vendor'],
          hw_version: response['hw_version'],
          hw_id: response['hw_id'],
          firmware: response['title'],
          firmware_version: response['release'],
          ndm_version: response.dig('ndm', 'exact') || response.dig('ndm', 'version'),
          arch: response['arch'],
          ndw_version: response.dig('ndw', 'version'),
          components: response['components'],
          sandbox: response['sandbox']
        }
      end

      def normalize_defaults(response)
        return {} unless response.is_a?(Hash)

        deep_normalize_keys(response)
      end

      def normalize_license(response)
        return {} unless response.is_a?(Hash)

        result = {
          valid: normalize_boolean(response['valid']),
          active: normalize_boolean(response['active']),
          expires: response['expires'],
          type: response['type'],
          features: normalize_features(response['features']),
          services: normalize_services(response['services'])
        }

        # Remove nil values for cleaner response
        result.compact
      end

      def normalize_features(features)
        return [] unless features.is_a?(Array)

        features.map do |feature|
          if feature.is_a?(Hash)
            normalize_keys(feature)
          else
            feature
          end
        end
      end

      def normalize_services(services)
        return [] unless services.is_a?(Array)

        services.map do |service|
          if service.is_a?(Hash)
            result = normalize_keys(service)
            normalize_booleans(result, %i[enabled active])
          else
            service
          end
        end
      end
    end
  end
end

