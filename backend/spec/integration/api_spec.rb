require 'spec_helper'
require 'rack/test'
require_relative '../../app'

RSpec.describe 'API Integration' do
  include Rack::Test::Methods

  def app
    App.freeze.app
  end

  before { stub_keenetic_auth }

  describe 'GET /' do
    it 'returns service status' do
      get '/'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['service']).to eq('keenetic-dashboard-api')
    end
  end

  describe 'GET /api/health' do
    it 'returns health status' do
      get '/api/health'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('healthy')
      expect(json['timestamp']).to be_a(String)
    end
  end

  describe 'GET /api/devices' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/hotspot')
        .to_return(status: 200, body: {
          'host' => [
            { 'mac' => 'AA:BB:CC:DD:EE:FF', 'name' => 'Device 1', 'active' => true },
            { 'mac' => '11:22:33:44:55:66', 'name' => 'Device 2', 'active' => false }
          ]
        }.to_json)
    end

    it 'returns list of devices' do
      get '/api/devices'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['devices'].size).to eq(2)
      expect(json['count']).to eq(2)
      expect(json['devices'].first['mac']).to eq('AA:BB:CC:DD:EE:FF')
    end
  end

  describe 'GET /api/devices/:mac' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/hotspot')
        .to_return(status: 200, body: {
          'host' => [
            { 'mac' => 'AA:BB:CC:DD:EE:FF', 'name' => 'My Device', 'ip' => '192.168.1.100' }
          ]
        }.to_json)
    end

    it 'returns single device' do
      get '/api/devices/AA:BB:CC:DD:EE:FF'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['device']['name']).to eq('My Device')
      expect(json['device']['ip']).to eq('192.168.1.100')
    end

    it 'returns 404 for unknown device' do
      get '/api/devices/XX:XX:XX:XX:XX:XX'

      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to match(/Not\s*Found/i)
    end
  end

  describe 'PATCH /api/devices/:mac' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/ip/hotspot/host')
        .to_return(status: 200, body: '{}')
    end

    it 'updates device name' do
      patch '/api/devices/AA:BB:CC:DD:EE:FF', { name: 'New Name' }.to_json, 
            'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
    end

    it 'returns error for invalid parameters' do
      patch '/api/devices/AA:BB:CC:DD:EE:FF', { invalid: 'param' }.to_json,
            'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
      json = JSON.parse(last_response.body)
      expect(json['error']).to eq('Bad Request')
    end
  end

  describe 'GET /api/system/resources' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/system')
        .to_return(status: 200, body: {
          'cpuload' => 25,
          'memtotal' => 262_144,
          'memfree' => 131_072,
          'uptime' => 86400
        }.to_json)
    end

    it 'returns system resources' do
      get '/api/system/resources'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['resources']['cpu']['load_percent']).to eq(25)
      expect(json['resources']['memory']['total']).to eq(262_144)
    end
  end

  describe 'GET /api/system/info' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/version')
        .to_return(status: 200, body: {
          'model' => 'Keenetic Giga',
          'release' => '4.1.0.0',
          'ndm' => { 'exact' => '4.1.0', 'version' => '4.1' },
          'ndw' => { 'version' => '4.1.0' }
        }.to_json)
    end

    it 'returns system info' do
      get '/api/system/info'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['info']['model']).to eq('Keenetic Giga')
    end
  end

  describe 'GET /api/network/interfaces' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: {
          'Bridge0' => { 'type' => 'bridge', 'state' => 'up', 'address' => '192.168.1.1' },
          'ISP' => { 'type' => 'wan', 'state' => 'up', 'connected' => true }
        }.to_json)
    end

    it 'returns network interfaces' do
      get '/api/network/interfaces'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['interfaces'].size).to eq(2)
      expect(json['count']).to eq(2)
    end
  end

  describe 'error handling' do
    it 'returns 404 for unknown routes' do
      get '/api/unknown'

      expect(last_response.status).to eq(404)
      json = JSON.parse(last_response.body)
      expect(json['error']).to eq('Not Found')
    end

    context 'when router is unreachable' do
      before do
        stub_request(:get, 'http://192.168.1.1/auth')
          .to_timeout
      end

      it 'returns 503 for connection errors' do
        get '/api/devices'

        expect(last_response.status).to eq(503)
        json = JSON.parse(last_response.body)
        expect(json['error']).to include('Timeout')
      end
    end
  end
end

