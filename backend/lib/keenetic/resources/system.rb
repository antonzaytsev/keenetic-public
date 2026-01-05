module Keenetic
  module Resources
    class System < Base
      # Get system resource usage (CPU, memory, storage)
      def resources
        response = get('/rci/show/system')
        normalize_resources(response)
      end

      # Get router system information (model, firmware, etc.)
      def info
        response = get('/rci/show/version')
        normalize_info(response)
      end

      # Get system uptime
      def uptime
        response = get('/rci/show/system')
        response['uptime'] if response.is_a?(Hash)
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
          ndm_version: response['ndm']['exact'] || response['ndm']['version'],
          arch: response['arch'],
          ndw_version: response['ndw']['version'],
          components: response['components'],
          sandbox: response['sandbox']
        }
      end
    end
  end
end

