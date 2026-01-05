require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::WiFi do
  let(:client) { Keenetic::Client.new }
  let(:wifi) { client.wifi }

  before { stub_keenetic_auth }

  let(:interface_response) do
    {
      'WifiMaster0' => {
        'type' => 'WifiMaster',
        'description' => '2.4GHz Radio',
        'state' => 'up',
        'channel' => 6,
        'band' => '2.4GHz'
      },
      'WifiMaster0/AccessPoint0' => {
        'type' => 'AccessPoint',
        'description' => 'Home',
        'ssid' => 'MyNetwork',
        'mac' => 'AA:BB:CC:DD:EE:00',
        'state' => 'up',
        'link' => 'up',
        'connected' => true,
        'channel' => 6,
        'band' => '2.4GHz',
        'authentication' => 'wpa2-psk',
        'encryption' => 'aes',
        'station-count' => 5,
        'txpower' => 20,
        'uptime' => 86400
      },
      'Bridge0' => {
        'type' => 'bridge',
        'description' => 'Home'
      }
    }
  end

  describe '#access_points' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'returns only Wi-Fi interfaces' do
      result = wifi.access_points

      expect(result.size).to eq(2)
      expect(result.map { |ap| ap[:id] }).to contain_exactly('WifiMaster0', 'WifiMaster0/AccessPoint0')
    end

    it 'returns normalized Wi-Fi data' do
      result = wifi.access_points
      ap = result.find { |a| a[:id] == 'WifiMaster0/AccessPoint0' }

      expect(ap[:ssid]).to eq('MyNetwork')
      expect(ap[:security]).to eq('wpa2-psk')
      expect(ap[:encryption]).to eq('aes')
      expect(ap[:channel]).to eq(6)
      expect(ap[:clients_count]).to eq(5)
    end

    context 'when no Wi-Fi interfaces exist' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/interface')
          .to_return(status: 200, body: { 'Bridge0' => { 'type' => 'bridge' } }.to_json)
      end

      it 'returns empty array' do
        expect(wifi.access_points).to eq([])
      end
    end
  end

  describe '#clients' do
    let(:associations_response) do
      {
        'station' => [
          {
            'mac' => 'AA:BB:CC:DD:EE:FF',
            'ap' => 'WifiMaster0/AccessPoint0',
            'authenticated' => true,
            'txrate' => 866700,
            'rxrate' => 780000,
            'uptime' => 3600,
            'txbytes' => 1_000_000,
            'rxbytes' => 500_000,
            'rssi' => -45,
            'mcs' => 9,
            'ht' => false,
            'mode' => 'ac',
            'gi' => 'short'
          }
        ]
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/associations')
        .to_return(status: 200, body: associations_response.to_json)
    end

    it 'returns connected Wi-Fi clients' do
      result = wifi.clients

      expect(result.size).to eq(1)
      expect(result.first[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result.first[:rssi]).to eq(-45)
      expect(result.first[:txrate]).to eq(866700)
    end

    context 'when no clients connected' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/associations')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty array' do
        expect(wifi.clients).to eq([])
      end
    end
  end

  describe '#access_point' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'finds access point by ID' do
      result = wifi.access_point('WifiMaster0/AccessPoint0')

      expect(result[:ssid]).to eq('MyNetwork')
    end

    it 'returns nil for unknown ID' do
      expect(wifi.access_point('Unknown0')).to be_nil
    end
  end

  describe '#configure' do
    it 'configures access point with all options' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'WifiMaster0/AccessPoint0' => {
              'ssid' => 'NewNetwork',
              'authentication' => 'wpa2-psk',
              'encryption' => 'aes',
              'key' => 'mysecretpassword',
              'up' => true
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      wifi.configure('WifiMaster0/AccessPoint0',
        ssid: 'NewNetwork',
        authentication: 'wpa2-psk',
        encryption: 'aes',
        key: 'mysecretpassword',
        up: true
      )

      expect(configure_stub).to have_been_requested
    end

    it 'configures only SSID' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'WifiMaster0/AccessPoint0' => {
              'ssid' => 'NewNetworkName'
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      wifi.configure('WifiMaster0/AccessPoint0', ssid: 'NewNetworkName')

      expect(configure_stub).to have_been_requested
    end

    it 'configures channel' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'WifiMaster0' => {
              'channel' => 11
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      wifi.configure('WifiMaster0', channel: 11)

      expect(configure_stub).to have_been_requested
    end

    it 'returns empty hash when no options provided' do
      result = wifi.configure('WifiMaster0/AccessPoint0')
      expect(result).to eq({})
    end
  end

  describe '#enable' do
    it 'enables access point' do
      enable_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'WifiMaster0/AccessPoint0' => {
              'up' => true
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      wifi.enable('WifiMaster0/AccessPoint0')

      expect(enable_stub).to have_been_requested
    end
  end

  describe '#disable' do
    it 'disables access point' do
      disable_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'interface' => {
            'WifiMaster0/AccessPoint1' => {
              'up' => false
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      wifi.disable('WifiMaster0/AccessPoint1')

      expect(disable_stub).to have_been_requested
    end
  end
end

