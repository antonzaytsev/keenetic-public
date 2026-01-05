require_relative 'keenetic/version'
require_relative 'keenetic/errors'
require_relative 'keenetic/configuration'
require_relative 'keenetic/client'
require_relative 'keenetic/resources/base'
require_relative 'keenetic/resources/devices'
require_relative 'keenetic/resources/system'
require_relative 'keenetic/resources/network'
require_relative 'keenetic/resources/wifi'

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

