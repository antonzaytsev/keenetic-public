require 'roda'
require 'json'

class App < Roda
  plugin :json
  plugin :json_parser
  plugin :halt
  plugin :error_handler
  plugin :not_found

  error do |e|
    response.status = 500
    { 
      error: 'Internal Server Error',
      message: e.message,
      timestamp: Time.now.iso8601
    }
  end

  not_found do
    response.status = 404
    { 
      error: 'Not Found',
      message: "Route not found: #{request.path}",
      timestamp: Time.now.iso8601
    }
  end

  route do |r|
    r.root do
      { status: 'ok', service: 'keenetic-dashboard-api' }
    end

    r.on 'api' do
      r.is 'health' do
        r.get do
          { status: 'healthy', timestamp: Time.now.iso8601 }
        end
      end
    end
  end
end
