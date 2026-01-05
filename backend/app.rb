require 'roda'
require 'json'
require_relative 'lib/keenetic'

# Configure Keenetic library with environment variables
Keenetic.configure do |config|
  config.host = ENV.fetch('KEENETIC_HOST', '192.168.1.1')
  config.login = ENV.fetch('KEENETIC_LOGIN', 'admin')
  config.password = ENV.fetch('KEENETIC_PASSWORD', '')
end

class App < Roda
  plugin :json
  plugin :json_parser
  plugin :halt
  plugin :error_handler
  plugin :not_found
  plugin :all_verbs

  def keenetic_client
    @keenetic_client ||= Keenetic.client
  end

  error do |e|
    response.status = case e
    when Keenetic::NotFoundError then 404
    when Keenetic::AuthenticationError then 401
    when Keenetic::ConnectionError, Keenetic::TimeoutError then 503
    else 500
    end

    { 
      error: e.class.name.split('::').last.gsub(/Error$/, ' Error').strip,
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

      # Devices endpoints
      r.on 'devices' do
        r.is do
          # GET /api/devices - list all devices
          r.get do
            devices = keenetic_client.devices.all
            { 
              devices: devices,
              count: devices.size,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.on String do |mac|
          # GET /api/devices/:mac - single device details
          r.get do
            device = keenetic_client.devices.find(mac: mac)
            { device: device, timestamp: Time.now.iso8601 }
          end

          # PATCH /api/devices/:mac - update device
          r.patch do
            params = r.params
            allowed_keys = %w[name access schedule]
            updates = params.select { |k, _| allowed_keys.include?(k) }
            
            if updates.empty?
              response.status = 400
              next { 
                error: 'Bad Request', 
                message: 'No valid update parameters provided. Allowed: name, access, schedule',
                timestamp: Time.now.iso8601
              }
            end

            result = keenetic_client.devices.update(mac: mac, **updates.transform_keys(&:to_sym))
            { 
              success: true, 
              result: result,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # System endpoints
      r.on 'system' do
        r.is 'resources' do
          r.get do
            resources = keenetic_client.system.resources
            { 
              resources: resources,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.is 'info' do
          r.get do
            info = keenetic_client.system.info
            { 
              info: info,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # Network endpoints
      r.on 'network' do
        r.is 'interfaces' do
          r.get do
            interfaces = keenetic_client.network.interfaces
            { 
              interfaces: interfaces,
              count: interfaces.size,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # Internet status endpoints
      r.on 'internet' do
        r.is 'status' do
          r.get do
            status = keenetic_client.internet.status
            { 
              status: status,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.is 'speed' do
          r.get do
            speed = keenetic_client.internet.speed
            { 
              speed: speed,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # Physical ports endpoints
      r.on 'ports' do
        r.is do
          r.get do
            ports = keenetic_client.ports.all
            { 
              ports: ports,
              count: ports.size,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # WiFi endpoints (bonus)
      r.on 'wifi' do
        r.is 'access-points' do
          r.get do
            aps = keenetic_client.wifi.access_points
            { 
              access_points: aps,
              count: aps.size,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.is 'clients' do
          r.get do
            clients = keenetic_client.wifi.clients
            { 
              clients: clients,
              count: clients.size,
              timestamp: Time.now.iso8601
            }
          end
        end
      end
    end
  end
end
