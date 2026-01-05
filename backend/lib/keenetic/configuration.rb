require 'logger'

module Keenetic
  class Configuration
    attr_accessor :host, :login, :password, :timeout, :open_timeout, :logger

    def initialize
      @host = ENV.fetch('KEENETIC_HOST', '192.168.1.1')
      @login = ENV.fetch('KEENETIC_LOGIN', 'admin')
      @password = ENV.fetch('KEENETIC_PASSWORD', '')
      @timeout = 30
      @open_timeout = 10
      @logger = Logger.new(nil)
    end

    def base_url
      "http://#{host}"
    end

    def validate!
      raise ConfigurationError, 'Host is required' if host.nil? || host.empty?
      raise ConfigurationError, 'Login is required' if login.nil? || login.empty?
      raise ConfigurationError, 'Password is required' if password.nil? || password.empty?
    end
  end
end

