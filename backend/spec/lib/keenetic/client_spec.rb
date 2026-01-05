require 'spec_helper'
require 'digest'

RSpec.describe Keenetic::Client do
  let(:client) { described_class.new }

  describe '#initialize' do
    it 'creates client with default configuration' do
      expect(client.config).to be_a(Keenetic::Configuration)
    end

    it 'raises error for invalid configuration' do
      Keenetic.configure { |c| c.password = '' }
      expect { described_class.new }.to raise_error(Keenetic::ConfigurationError)
    end
  end

  describe '#authenticate!' do
    context 'when authentication succeeds' do
      before { stub_keenetic_auth }

      it 'authenticates successfully' do
        expect(client.authenticate!).to be true
        expect(client).to be_authenticated
      end

      it 'sends correct authentication hash' do
        stub_request(:get, 'http://192.168.1.1/auth')
          .to_return(
            status: 401,
            headers: {
              'X-NDM-Challenge' => 'challenge123',
              'X-NDM-Realm' => 'KEENETIC'
            }
          )

        expected_md5 = Digest::MD5.hexdigest('admin:KEENETIC:test_password')
        expected_hash = Digest::SHA256.hexdigest("challenge123#{expected_md5}")

        auth_stub = stub_request(:post, 'http://192.168.1.1/auth')
          .with(body: { login: 'admin', password: expected_hash }.to_json)
          .to_return(status: 200, body: '{}')

        client.authenticate!

        expect(auth_stub).to have_been_requested
      end
    end

    context 'when already authenticated' do
      it 'returns immediately if session is valid' do
        stub_request(:get, 'http://192.168.1.1/auth')
          .to_return(status: 200, body: '{"authenticated": true}')

        expect(client.authenticate!).to be true
        expect(client).to be_authenticated
      end
    end

    context 'when authentication fails' do
      it 'raises AuthenticationError' do
        stub_request(:get, 'http://192.168.1.1/auth')
          .to_return(
            status: 401,
            headers: {
              'X-NDM-Challenge' => 'challenge',
              'X-NDM-Realm' => 'KEENETIC'
            }
          )

        stub_request(:post, 'http://192.168.1.1/auth')
          .to_return(status: 401, body: '{"error": "invalid credentials"}')

        expect { client.authenticate! }.to raise_error(Keenetic::AuthenticationError)
      end
    end

    context 'when challenge headers are missing' do
      it 'raises AuthenticationError with context' do
        stub_request(:get, 'http://192.168.1.1/auth')
          .to_return(status: 401, headers: {})

        expect { client.authenticate! }.to raise_error(
          Keenetic::AuthenticationError,
          /Missing challenge headers.*host=192\.168\.1\.1.*login=admin/
        )
      end
    end
  end

  describe '#get' do
    before { stub_keenetic_auth }

    it 'makes authenticated GET request' do
      stub_request(:get, 'http://192.168.1.1/rci/show/system')
        .to_return(status: 200, body: '{"cpuload": 10}')

      result = client.get('/rci/show/system')
      expect(result).to eq({ 'cpuload' => 10 })
    end

    it 'handles query parameters' do
      stub_request(:get, 'http://192.168.1.1/rci/test?foo=bar')
        .to_return(status: 200, body: '{}')

      client.get('/rci/test', foo: 'bar')

      expect(WebMock).to have_requested(:get, 'http://192.168.1.1/rci/test?foo=bar')
    end
  end

  describe '#post' do
    before { stub_keenetic_auth }

    it 'makes authenticated POST request with JSON body' do
      stub_request(:post, 'http://192.168.1.1/rci/ip/hotspot/host')
        .with(
          body: '{"mac":"AA:BB:CC:DD:EE:FF","name":"Test Device"}',
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(status: 200, body: '{"success": true}')

      result = client.post('/rci/ip/hotspot/host', mac: 'AA:BB:CC:DD:EE:FF', name: 'Test Device')
      expect(result).to eq({ 'success' => true })
    end
  end

  describe 'resource accessors' do
    it 'provides devices resource' do
      expect(client.devices).to be_a(Keenetic::Resources::Devices)
    end

    it 'provides system resource' do
      expect(client.system).to be_a(Keenetic::Resources::System)
    end

    it 'provides network resource' do
      expect(client.network).to be_a(Keenetic::Resources::Network)
    end

    it 'provides wifi resource' do
      expect(client.wifi).to be_a(Keenetic::Resources::WiFi)
    end

    it 'memoizes resource instances' do
      expect(client.devices).to be(client.devices)
    end
  end

  describe 'error handling' do
    before { stub_keenetic_auth }

    it 'raises NotFoundError for 404 responses' do
      stub_request(:get, 'http://192.168.1.1/rci/unknown')
        .to_return(status: 404)

      expect { client.get('/rci/unknown') }.to raise_error(Keenetic::NotFoundError)
    end

    it 'raises ApiError for other error responses' do
      stub_request(:get, 'http://192.168.1.1/rci/error')
        .to_return(status: 500, body: 'Internal Error')

      expect { client.get('/rci/error') }.to raise_error(Keenetic::ApiError) do |error|
        expect(error.status_code).to eq(500)
      end
    end

    it 'raises TimeoutError when request times out' do
      stub_request(:get, 'http://192.168.1.1/rci/slow')
        .to_timeout

      expect { client.get('/rci/slow') }.to raise_error(Keenetic::TimeoutError)
    end
  end
end

