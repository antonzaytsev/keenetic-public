require 'typhoeus'
require 'json'
require 'digest'

module Keenetic
  class Client
    attr_reader :config

    def initialize(config = nil)
      @config = config || Keenetic.configuration
      @config.validate!
      @cookies = {}
      @authenticated = false
      @mutex = Mutex.new
    end

    def devices
      @devices ||= Resources::Devices.new(self)
    end

    def system
      @system ||= Resources::System.new(self)
    end

    def network
      @network ||= Resources::Network.new(self)
    end

    def wifi
      @wifi ||= Resources::WiFi.new(self)
    end

    def internet
      @internet ||= Resources::Internet.new(self)
    end

    def ports
      @ports ||= Resources::Ports.new(self)
    end

    def get(path, params = {})
      request(:get, path, params: params)
    end

    def post(path, body = {})
      request(:post, path, body: body)
    end

    def authenticated?
      @authenticated
    end

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

