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

  describe '#mesh_members' do
    let(:mws_member_response) do
      {
        'show' => {
          'mws' => {
            'member' => [
              {
                'cid' => 'extender-1-uuid',
                'model' => 'Air (KN-1613)',
                'mac' => '50:FF:20:77:30:84',
                'known-host' => 'Keenetic Air 1',
                'ip' => '192.168.0.240',
                'mode' => 'extender',
                'hw-id' => 'KN-1613',
                'fw' => '4.3.6.3',
                'associations' => 5,
                'system' => {
                  'cpuload' => 4,
                  'memory' => '39384/131072',
                  'uptime' => '83013'
                },
                'backhaul' => {
                  'uplink' => 'FastEthernet0/Vlan1',
                  'speed' => '100',
                  'duplex' => 'full'
                }
              },
              {
                'cid' => 'extender-2-uuid',
                'model' => 'Air (KN-1613)',
                'mac' => '50:FF:20:77:35:DF',
                'known-host' => 'Keenetic Air 2',
                'ip' => '192.168.0.241',
                'mode' => 'extender',
                'hw-id' => 'KN-1613',
                'fw' => '4.3.6.3',
                'associations' => 20,
                'system' => {
                  'cpuload' => 25,
                  'uptime' => '207037'
                },
                'backhaul' => {
                  'uplink' => 'WifiMaster1/AccessPoint0',
                  'speed' => '866'
                }
              }
            ]
          }
        }
      }
    end

    let(:version_response) do
      {
        'show' => {
          'version' => {
            'model' => 'Racer',
            'hw_id' => 'KN-4010',
            'hw_version' => '10408000',
            'mac' => '50:FF:20:DD:0B:BB',
            'release' => '4.03.C.6.3-9',
            'description' => 'Keenetic Racer'
          }
        }
      }
    end

    let(:system_response) do
      {
        'show' => {
          'system' => {
            'name' => 'Main Router',
            'uptime' => '86400'
          }
        }
      }
    end

    let(:associations_response) do
      {
        'show' => {
          'associations' => {
            'station' => [
              { 'mac' => 'AA:BB:CC:DD:EE:01' },
              { 'mac' => 'AA:BB:CC:DD:EE:02' },
              { 'mac' => 'AA:BB:CC:DD:EE:03' }
            ]
          }
        }
      }
    end

    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [
          { 'show' => { 'mws' => { 'member' => {} } } },
          { 'show' => { 'version' => {} } },
          { 'show' => { 'system' => {} } },
          { 'show' => { 'associations' => {} } }
        ].to_json)
        .to_return(status: 200, body: [
          mws_member_response,
          version_response,
          system_response,
          associations_response
        ].to_json)
    end

    it 'returns controller and extenders' do
      result = wifi.mesh_members

      expect(result.size).to eq(3)
      expect(result.map { |m| m[:mode] }).to eq(['controller', 'extender', 'extender'])
    end

    it 'returns controller as first element' do
      result = wifi.mesh_members
      controller = result.first

      expect(controller[:id]).to eq('controller')
      expect(controller[:mode]).to eq('controller')
      expect(controller[:name]).to eq('Main Router')
      expect(controller[:model]).to eq('Racer (KN-4010)')
      expect(controller[:version]).to eq('4.03.C.6.3-9')
      expect(controller[:clients_count]).to eq(3)
      expect(controller[:online]).to be true
    end

    it 'normalizes extender data correctly' do
      result = wifi.mesh_members
      extender1 = result[1]

      expect(extender1[:id]).to eq('extender-1-uuid')
      expect(extender1[:mac]).to eq('50:FF:20:77:30:84')
      expect(extender1[:name]).to eq('Keenetic Air 1')
      expect(extender1[:model]).to eq('Air (KN-1613)')
      expect(extender1[:mode]).to eq('extender')
      expect(extender1[:ip]).to eq('192.168.0.240')
      expect(extender1[:version]).to eq('4.3.6.3')
      expect(extender1[:uptime]).to eq(83013)
      expect(extender1[:clients_count]).to eq(5)
      expect(extender1[:via]).to eq('FastEthernet0/Vlan1')
      expect(extender1[:connection_speed]).to eq('100')
      expect(extender1[:online]).to be true
    end

    it 'handles extender connected via Wi-Fi' do
      result = wifi.mesh_members
      extender2 = result[2]

      expect(extender2[:name]).to eq('Keenetic Air 2')
      expect(extender2[:via]).to eq('WifiMaster1/AccessPoint0')
      expect(extender2[:connection_speed]).to eq('866')
    end

    context 'when no extenders exist' do
      let(:mws_member_response) do
        { 'show' => { 'mws' => { 'member' => [] } } }
      end

      it 'returns only controller' do
        result = wifi.mesh_members

        expect(result.size).to eq(1)
        expect(result.first[:mode]).to eq('controller')
      end
    end

    context 'when mws member is a single object instead of array' do
      let(:mws_member_response) do
        {
          'show' => {
            'mws' => {
              'member' => {
                'cid' => 'single-extender-uuid',
                'model' => 'Air (KN-1613)',
                'mac' => '50:FF:20:77:30:84',
                'known-host' => 'Single Extender',
                'ip' => '192.168.0.240',
                'mode' => 'extender',
                'hw-id' => 'KN-1613',
                'fw' => '4.3.6.3',
                'associations' => 3,
                'system' => { 'uptime' => '1000' },
                'backhaul' => { 'uplink' => 'FastEthernet0/Vlan1', 'speed' => '100' }
              }
            }
          }
        }
      end

      it 'handles single member as array' do
        result = wifi.mesh_members

        expect(result.size).to eq(2)
        expect(result[1][:name]).to eq('Single Extender')
      end
    end

    context 'when version response is empty' do
      let(:version_response) do
        { 'show' => { 'version' => {} } }
      end

      it 'returns only extenders without controller' do
        result = wifi.mesh_members

        expect(result.size).to eq(2)
        expect(result.all? { |m| m[:mode] == 'extender' }).to be true
      end
    end

    context 'when associations response has single station' do
      let(:associations_response) do
        {
          'show' => {
            'associations' => {
              'station' => { 'mac' => 'AA:BB:CC:DD:EE:01' }
            }
          }
        }
      end

      it 'counts single client correctly' do
        result = wifi.mesh_members
        controller = result.first

        expect(controller[:clients_count]).to eq(1)
      end
    end

    context 'when associations response is empty' do
      let(:associations_response) do
        { 'show' => { 'associations' => {} } }
      end

      it 'returns zero client count for controller' do
        result = wifi.mesh_members
        controller = result.first

        expect(controller[:clients_count]).to eq(0)
      end
    end
  end
end

