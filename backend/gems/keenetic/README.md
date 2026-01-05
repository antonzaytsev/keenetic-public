# Keenetic

Ruby client for Keenetic router REST API.

## Installation

```ruby
gem 'keenetic', path: 'gems/keenetic'
```

## Configuration

```ruby
Keenetic.configure do |config|
  config.host = '192.168.1.1'
  config.login = 'admin'
  config.password = 'your_password'
  config.timeout = 30                    # optional
  config.logger = Logger.new($stdout)    # optional
end

client = Keenetic.client
```

## Usage

```ruby
# Devices
client.devices.all                           # List all devices
client.devices.active                        # Connected devices only
client.devices.find(mac: 'AA:BB:CC:DD:EE:FF')
client.devices.update(mac: 'AA:BB:CC:DD:EE:FF', name: 'My Phone')

# System
client.system.resources    # CPU, memory, uptime
client.system.info         # Model, firmware version

# Network
client.network.interfaces  # All network interfaces

# WiFi
client.wifi.access_points  # WiFi networks
client.wifi.clients        # Connected WiFi clients

# Internet
client.internet.status     # Connection status
client.internet.speed      # WAN speed stats

# Ports
client.ports.all           # Physical port statuses
```

## Error Handling

```ruby
begin
  client.devices.all
rescue Keenetic::AuthenticationError
  # Invalid credentials
rescue Keenetic::ConnectionError
  # Router unreachable
rescue Keenetic::TimeoutError
  # Request timed out
rescue Keenetic::NotFoundError
  # Resource not found
rescue Keenetic::ApiError => e
  # Other API errors
  e.status_code
  e.response_body
end
```

## API Reference

See [KEENETIC_API.md](KEENETIC_API.md) for complete API documentation.

