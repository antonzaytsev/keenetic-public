require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Internet do
  let(:client) { Keenetic::Client.new }
  let(:internet) { client.internet }

  before { stub_keenetic_auth }

  describe '#status' do
    let(:status_response) do
      {
        'internet' => true,
        'gateway' => '10.0.0.1',
        'dns' => ['8.8.8.8', '8.8.4.4'],
        'checked' => '2024-01-15T12:00:00Z',
        'checking' => false
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/internet/status')
        .to_return(status: 200, body: status_response.to_json)
    end

    it 'returns normalized internet status' do
      result = internet.status

      expect(result[:connected]).to be true
      expect(result[:gateway]).to eq('10.0.0.1')
      expect(result[:dns]).to eq(['8.8.8.8', '8.8.4.4'])
      expect(result[:checked]).to eq('2024-01-15T12:00:00Z')
      expect(result[:checking]).to be false
    end

    context 'when not connected' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/internet/status')
          .to_return(status: 200, body: { 'internet' => false }.to_json)
      end

      it 'returns connected as false' do
        result = internet.status
        expect(result[:connected]).to be false
      end
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/internet/status')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty hash with defaults' do
        result = internet.status
        expect(result[:connected]).to be false
        expect(result[:dns]).to eq([])
      end
    end
  end

  describe '#speed' do
    let(:interface_response) do
      {
        'ISP' => {
          'defaultgw' => true,
          'rxbytes' => 1_000_000,
          'txbytes' => 500_000,
          'rxpackets' => 10000,
          'txpackets' => 5000,
          'uptime' => 86400
        },
        'Bridge0' => {
          'defaultgw' => false,
          'rxbytes' => 2_000_000,
          'txbytes' => 1_000_000
        }
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'returns WAN interface traffic stats' do
      result = internet.speed

      expect(result[:interface]).to eq('ISP')
      expect(result[:rxbytes]).to eq(1_000_000)
      expect(result[:txbytes]).to eq(500_000)
      expect(result[:uptime]).to eq(86400)
    end

    context 'when no WAN interface exists' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/interface')
          .to_return(status: 200, body: {
            'Bridge0' => { 'defaultgw' => false }
          }.to_json)
      end

      it 'returns nil' do
        expect(internet.speed).to be_nil
      end
    end
  end

  describe '#configure' do
    it 'configures PPPoE connection' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'ISP' => {
              'pppoe' => {
                'service' => 'MyISP',
                'username' => 'user@isp.com',
                'password' => 'secret'
              },
              'up' => true
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      internet.configure('ISP',
        pppoe: { service: 'MyISP', username: 'user@isp.com', password: 'secret' },
        up: true
      )

      expect(configure_stub).to have_been_requested
    end

    it 'configures static IP' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'ISP' => {
              'address' => '203.0.113.50',
              'mask' => '255.255.255.0',
              'gateway' => '203.0.113.1'
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      internet.configure('ISP',
        address: '203.0.113.50',
        mask: '255.255.255.0',
        gateway: '203.0.113.1'
      )

      expect(configure_stub).to have_been_requested
    end

    it 'configures DHCP' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'ISP' => {
              'ip' => { 'dhcp' => true },
              'up' => true
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      internet.configure('ISP', dhcp: true, up: true)

      expect(configure_stub).to have_been_requested
    end

    it 'returns empty hash when no options provided' do
      result = internet.configure('ISP')
      expect(result).to eq({})
    end
  end
end

