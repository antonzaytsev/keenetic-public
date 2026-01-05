module Keenetic
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class AuthenticationError < Error; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class NotFoundError < Error; end
  class ApiError < Error
    attr_reader :status_code, :response_body

    def initialize(message, status_code: nil, response_body: nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
    end
  end
end

