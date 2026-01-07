require_relative 'keenetic/version'
require_relative 'keenetic/errors'
require_relative 'keenetic/configuration'
require_relative 'keenetic/client'
require_relative 'keenetic/resources/base'
require_relative 'keenetic/resources/devices'
require_relative 'keenetic/resources/system'
require_relative 'keenetic/resources/network'
require_relative 'keenetic/resources/wifi'
require_relative 'keenetic/resources/internet'
require_relative 'keenetic/resources/ports'
require_relative 'keenetic/resources/policies'
require_relative 'keenetic/resources/dhcp'
require_relative 'keenetic/resources/routing'
require_relative 'keenetic/resources/logs'

# Keenetic Router API Client
#
# A Ruby client for interacting with Keenetic router's REST API.
# Supports authentication, device management, system monitoring, and network interfaces.
#
# == Configuration
#
#   Keenetic.configure do |config|
#     config.host = '192.168.1.1'
#     config.login = 'admin'
#     config.password = 'your_password'
#     config.timeout = 30          # optional, default: 30
#     config.logger = Logger.new($stdout)  # optional
#   end
#
# == Usage
#
#   client = Keenetic.client
#
#   # Devices
#   client.devices.all                    # List all devices
#   client.devices.active                 # Only connected devices
#   client.devices.find(mac: 'AA:BB:...')  # Find by MAC
#   client.devices.update(mac: 'AA:BB:...', name: 'My Phone')
#
#   # System
#   client.system.resources   # CPU, memory, uptime
#   client.system.info        # Model, firmware version
#
#   # Network
#   client.network.interfaces  # All network interfaces
#
#   # WiFi
#   client.wifi.access_points  # WiFi networks
#   client.wifi.clients        # Connected WiFi clients
#
#   # Internet
#   client.internet.status     # Internet connection status
#   client.internet.speed      # Current WAN speed stats
#
#   # Ports
#   client.ports.all           # Physical port statuses
#
# == Error Handling
#
#   begin
#     client.devices.all
#   rescue Keenetic::AuthenticationError => e
#     # Invalid credentials
#   rescue Keenetic::ConnectionError => e
#     # Router unreachable
#   rescue Keenetic::TimeoutError => e
#     # Request timed out
#   rescue Keenetic::NotFoundError => e
#     # Resource not found
#   rescue Keenetic::ApiError => e
#     # Other API errors (e.status_code, e.response_body)
#   end
#
module Keenetic
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Convenience method to create a new client with current configuration
    def client
      Client.new(configuration)
    end
  end
end

