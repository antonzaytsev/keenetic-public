require 'typhoeus'
require 'json'
require 'digest'

module Keenetic
  # HTTP client for Keenetic router API.
  #
  # == Authentication Flow
  # Keenetic uses a challenge-response authentication mechanism:
  #
  #   Step 1: GET /auth
  #           Response: HTTP 401 with headers X-NDM-Challenge and X-NDM-Realm
  #           Also sets session cookie
  #
  #   Step 2: Calculate authentication hash
  #           md5_hash = MD5(login + ":" + realm + ":" + password)
  #           auth_hash = SHA256(challenge + md5_hash)
  #
  #   Step 3: POST /auth
  #           Body: {"login": "admin", "password": "<auth_hash>"}
  #           Response: HTTP 200 on success
  #           Session maintained via cookies
  #
  # == Request Types
  #
  # === Reading Data (GET)
  #   GET /rci/show/<path>
  #   Example: GET /rci/show/system, GET /rci/show/ip/hotspot
  #
  # === Writing Data (POST - Batch Format)
  #   POST /rci/
  #   Body: Array of commands (MUST be array, even for single command)
  #   Example: [{"ip":{"hotspot":{"host":{"mac":"aa:bb:cc:dd:ee:ff","permit":true}}}}]
  #
  # == Thread Safety
  # The client uses a mutex to prevent concurrent authentication attempts.
  # Resource instances are memoized and thread-safe for reading.
  #
  class Client
    attr_reader :config

    # Create a new client instance.
    #
    # @param config [Configuration, nil] Optional configuration (uses global if nil)
    # @raise [ConfigurationError] if configuration is invalid
    #
    def initialize(config = nil)
      @config = config || Keenetic.configuration
      @config.validate!
      @cookies = {}
      @authenticated = false
      @mutex = Mutex.new
    end

    # @return [Resources::Devices] Device management resource
    def devices
      @devices ||= Resources::Devices.new(self)
    end

    # @return [Resources::System] System information resource
    def system
      @system ||= Resources::System.new(self)
    end

    # @return [Resources::Network] Network interfaces resource
    def network
      @network ||= Resources::Network.new(self)
    end

    # @return [Resources::WiFi] Wi-Fi resource
    def wifi
      @wifi ||= Resources::WiFi.new(self)
    end

    # @return [Resources::Internet] Internet status resource
    def internet
      @internet ||= Resources::Internet.new(self)
    end

    # @return [Resources::Ports] Physical ports resource
    def ports
      @ports ||= Resources::Ports.new(self)
    end

    # @return [Resources::Policies] Routing policies resource
    def policies
      @policies ||= Resources::Policies.new(self)
    end

    # @return [Resources::DHCP] DHCP resource
    def dhcp
      @dhcp ||= Resources::DHCP.new(self)
    end

    # @return [Resources::Routing] Routing resource
    def routing
      @routing ||= Resources::Routing.new(self)
    end

    # @return [Resources::Logs] System logs resource
    def logs
      @logs ||= Resources::Logs.new(self)
    end

    # Make a GET request to the router API.
    #
    # == Keenetic API
    #   GET http://<host>/rci/show/<path>
    #
    # @param path [String] API path (e.g., '/rci/show/system')
    # @param params [Hash] Optional query parameters
    # @return [Hash, Array, nil] Parsed JSON response
    #
    def get(path, params = {})
      request(:get, path, params: params)
    end

    # Make a POST request to the router API.
    #
    # == Keenetic API
    #   POST http://<host>/rci/<path>
    #   Content-Type: application/json
    #
    # @param path [String] API path
    # @param body [Hash] Request body (will be JSON encoded)
    # @return [Hash, Array, nil] Parsed JSON response
    #
    def post(path, body = {})
      request(:post, path, body: body)
    end

    # Execute multiple commands in a single batch request.
    #
    # == Keenetic API
    #   POST http://<host>/rci/
    #   Content-Type: application/json
    #   Body: Array of command objects
    #
    # == Important
    # All write operations to Keenetic MUST use batch format (array).
    # Even single commands must be wrapped in an array.
    #
    # @param commands [Array<Hash>] Array of command hashes
    # @return [Array] Array of responses in the same order as commands
    # @raise [ArgumentError] if commands is not a non-empty array
    #
    # @example Read multiple values
    #   client.batch([
    #     { 'show' => { 'system' => {} } },
    #     { 'show' => { 'version' => {} } }
    #   ])
    #
    # @example Write command (update device)
    #   client.batch([
    #     { 'known' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'name' => 'My Device' } } }
    #   ])
    #
    def batch(commands)
      raise ArgumentError, 'Commands must be an array' unless commands.is_a?(Array)
      raise ArgumentError, 'Commands array cannot be empty' if commands.empty?

      request(:post, '/rci/', body: commands)
    end

    # Check if client is authenticated.
    # @return [Boolean]
    def authenticated?
      @authenticated
    end

    # Perform authentication (thread-safe).
    #
    # Called automatically before first request.
    # Uses mutex to prevent concurrent authentication attempts.
    #
    # @return [Boolean] true on success
    # @raise [AuthenticationError] on failure
    # @raise [TimeoutError] if connection times out
    # @raise [ConnectionError] if router is unreachable
    #
    def authenticate!
      @mutex.synchronize do
        return true if @authenticated

        perform_authentication
      end
    end

    private

    def request(method, path, options = {})
      authenticate! unless @authenticated || path == '/auth'

      url = "#{config.base_url}#{path}"
      
      request_options = {
        method: method,
        timeout: config.timeout,
        connecttimeout: config.open_timeout,
        headers: build_headers,
        accept_encoding: 'gzip'
      }

      if options[:params] && !options[:params].empty?
        url += "?#{URI.encode_www_form(options[:params])}"
      end

      if options[:body]
        request_options[:body] = options[:body].to_json
        request_options[:headers]['Content-Type'] = 'application/json'
      end

      config.logger.debug { "Keenetic: #{method.upcase} #{url}" }

      response = Typhoeus::Request.new(url, request_options).run

      handle_response(response)
    end

    def build_headers
      headers = {
        'Accept' => 'application/json',
        'User-Agent' => "Keenetic Ruby Client/#{VERSION}"
      }
      
      headers['Cookie'] = format_cookies unless @cookies.empty?
      headers
    end

    def format_cookies
      @cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
    end

    def parse_cookies(response)
      return unless response.headers

      set_cookie_headers = response.headers['Set-Cookie']
      return unless set_cookie_headers

      cookies = set_cookie_headers.is_a?(Array) ? set_cookie_headers : [set_cookie_headers]
      
      cookies.each do |cookie|
        parts = cookie.split(';').first
        next unless parts

        name, value = parts.split('=', 2)
        @cookies[name.strip] = value&.strip if name
      end
    end

    def handle_response(response)
      parse_cookies(response)

      if response.timed_out?
        raise TimeoutError, "Request timed out after #{config.timeout}s"
      end

      if response.code == 0
        raise ConnectionError, "Connection failed: #{response.return_message}"
      end

      unless response.success? || response.code == 401
        if response.code == 404
          raise NotFoundError, "Resource not found"
        end
        raise ApiError.new(
          "API request failed with status #{response.code}",
          status_code: response.code,
          response_body: response.body
        )
      end

      return nil if response.body.nil? || response.body.empty?

      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
    end

    def perform_authentication
      # Step 1: Get challenge from router
      url = "#{config.base_url}/auth"
      
      challenge_response = Typhoeus::Request.new(url, {
        method: :get,
        timeout: config.timeout,
        connecttimeout: config.open_timeout,
        headers: { 'Accept' => 'application/json' }
      }).run

      if challenge_response.timed_out?
        raise TimeoutError, auth_error_context("Authentication timed out after #{config.timeout}s")
      end

      if challenge_response.code == 0
        raise ConnectionError, auth_error_context("Connection failed: #{challenge_response.return_message}")
      end

      parse_cookies(challenge_response)

      # If already authenticated (returns 200), we're done
      if challenge_response.code == 200
        @authenticated = true
        config.logger.info { "Keenetic: Already authenticated" }
        return true
      end

      unless challenge_response.code == 401
        raise AuthenticationError, auth_error_context("Unexpected response: HTTP #{challenge_response.code}")
      end

      headers = challenge_response.headers || {}
      challenge = headers['X-NDM-Challenge']
      realm = headers['X-NDM-Realm']

      unless challenge && realm
        raise AuthenticationError, auth_error_context("Missing challenge headers from router")
      end

      config.logger.debug { "Keenetic: Got challenge, realm=#{realm}" }

      # Step 2: Calculate authentication hash
      # MD5(login:realm:password) -> then SHA256(challenge + md5_hash)
      md5_hash = Digest::MD5.hexdigest("#{config.login}:#{realm}:#{config.password}")
      auth_hash = Digest::SHA256.hexdigest("#{challenge}#{md5_hash}")

      # Step 3: Send authentication request
      auth_response = Typhoeus::Request.new(url, {
        method: :post,
        timeout: config.timeout,
        connecttimeout: config.open_timeout,
        headers: build_headers.merge('Content-Type' => 'application/json'),
        body: { login: config.login, password: auth_hash }.to_json
      }).run

      parse_cookies(auth_response)

      if auth_response.code == 200
        @authenticated = true
        config.logger.info { "Keenetic: Authentication successful" }
        true
      else
        raise AuthenticationError, auth_error_context("Authentication failed: HTTP #{auth_response.code}")
      end
    end

    def auth_error_context(message)
      details = [
        message,
        "host=#{config.host}",
        "login=#{config.login}",
        "timeout=#{config.timeout}s",
        "connect_timeout=#{config.open_timeout}s"
      ]
      details.join(' | ')
    end
  end
end

