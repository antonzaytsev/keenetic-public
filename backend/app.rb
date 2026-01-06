require 'roda'
require 'json'
require 'uri'
require_relative 'gems/keenetic/lib/keenetic'

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

        r.on String do |mac_param|
          # Decode URL-encoded MAC address
          mac = URI.decode_www_form_component(mac_param)
          
          # GET /api/devices/:mac - single device details
          r.get do
            device = keenetic_client.devices.find(mac: mac)
            { device: device, timestamp: Time.now.iso8601 }
          end

          # PATCH /api/devices/:mac - update device
          r.patch do
            params = r.params
            allowed_keys = %w[name access schedule policy static_ip]
            updates = params.select { |k, _| allowed_keys.include?(k) }
            
            if updates.empty?
              response.status = 400
              next { 
                error: 'Bad Request', 
                message: 'No valid update parameters provided. Allowed: name, access, schedule, policy, static_ip',
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

        r.is 'mesh' do
          r.get do
            members = keenetic_client.wifi.mesh_members
            { 
              members: members,
              count: members.size,
              timestamp: Time.now.iso8601
            }
          end
        end
      end

      # Policies endpoints
      r.on 'policies' do
        r.is do
          # GET /api/policies - list all routing policies
          r.get do
            policies = keenetic_client.policies.all
            device_assignments = keenetic_client.policies.device_assignments
            {
              policies: policies,
              device_assignments: device_assignments,
              count: policies.size,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.on String do |policy_id|
          policy_id = URI.decode_www_form_component(policy_id)

          # GET /api/policies/:id - get specific policy
          r.get do
            policy = keenetic_client.policies.find(id: policy_id)
            { policy: policy, timestamp: Time.now.iso8601 }
          end
        end
      end

      # DHCP endpoints
      r.on 'dhcp' do
        r.is 'leases' do
          # GET /api/dhcp/leases - list active DHCP leases
          r.get do
            leases = keenetic_client.dhcp.leases
            {
              leases: leases,
              count: leases.size,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.on 'bindings' do
          r.is do
            # GET /api/dhcp/bindings - list static DHCP bindings
            r.get do
              bindings = keenetic_client.dhcp.bindings
              {
                bindings: bindings,
                count: bindings.size,
                timestamp: Time.now.iso8601
              }
            end

            # POST /api/dhcp/bindings - create static DHCP binding
            r.post do
              params = r.params
              mac = params['mac']
              ip = params['ip']
              name = params['name']

              if mac.nil? || mac.empty? || ip.nil? || ip.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'Both mac and ip are required',
                  timestamp: Time.now.iso8601
                }
              end

              result = keenetic_client.dhcp.create_binding(mac: mac, ip: ip, name: name)
              {
                success: true,
                result: result,
                timestamp: Time.now.iso8601
              }
            end
          end

          r.on String do |mac_param|
            mac = URI.decode_www_form_component(mac_param)

            # GET /api/dhcp/bindings/:mac - get specific binding
            r.get do
              binding = keenetic_client.dhcp.find_binding(mac: mac)
              if binding.nil?
                response.status = 404
                next {
                  error: 'Not Found',
                  message: "DHCP binding not found for MAC: #{mac}",
                  timestamp: Time.now.iso8601
                }
              end
              { binding: binding, timestamp: Time.now.iso8601 }
            end

            # PATCH /api/dhcp/bindings/:mac - update binding
            r.patch do
              params = r.params
              ip = params['ip']
              name = params['name']

              if ip.nil? && name.nil?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'At least one of ip or name is required',
                  timestamp: Time.now.iso8601
                }
              end

              result = keenetic_client.dhcp.update_binding(mac: mac, ip: ip, name: name)
              {
                success: true,
                result: result,
                timestamp: Time.now.iso8601
              }
            end

            # DELETE /api/dhcp/bindings/:mac - delete binding
            r.delete do
              result = keenetic_client.dhcp.delete_binding(mac: mac)
              {
                success: true,
                result: result,
                timestamp: Time.now.iso8601
              }
            end
          end
        end
      end

      # Routing endpoints
      r.on 'routing' do
        r.is 'routes' do
          r.get do
            routes = keenetic_client.routing.routes
            {
              routes: routes,
              count: routes.size,
              timestamp: Time.now.iso8601
            }
          end

          r.post do
            params = r.params
            destination = params['destination']
            mask = params['mask']
            gateway = params['gateway']
            interface_name = params['interface']
            metric = params['metric']

            if destination.nil? || destination.empty? || mask.nil? || mask.empty?
              response.status = 400
              next {
                error: 'Bad Request',
                message: 'Both destination and mask are required',
                timestamp: Time.now.iso8601
              }
            end

            if gateway.nil? && interface_name.nil?
              response.status = 400
              next {
                error: 'Bad Request',
                message: 'Either gateway or interface is required',
                timestamp: Time.now.iso8601
              }
            end

            result = keenetic_client.routing.create_route(
              destination: destination,
              mask: mask,
              gateway: gateway,
              interface: interface_name,
              metric: metric&.to_i
            )
            {
              success: true,
              result: result,
              timestamp: Time.now.iso8601
            }
          end

          r.delete do
            params = r.params
            destination = params['destination']
            mask = params['mask']

            if destination.nil? || destination.empty? || mask.nil? || mask.empty?
              response.status = 400
              next {
                error: 'Bad Request',
                message: 'Both destination and mask are required',
                timestamp: Time.now.iso8601
              }
            end

            result = keenetic_client.routing.delete_route(destination: destination, mask: mask)
            {
              success: true,
              result: result,
              timestamp: Time.now.iso8601
            }
          end
        end

        r.is 'arp' do
          r.get do
            arp_table = keenetic_client.routing.arp_table
            {
              arp_table: arp_table,
              count: arp_table.size,
              timestamp: Time.now.iso8601
            }
          end
        end
      end
    end
  end
end
