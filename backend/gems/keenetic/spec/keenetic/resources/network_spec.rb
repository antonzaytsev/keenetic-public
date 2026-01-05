require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Network do
  let(:client) { Keenetic::Client.new }
  let(:network) { client.network }

  before { stub_keenetic_auth }

  let(:interface_response) do
    {
      'GigabitEthernet0' => {
        'description' => 'WAN',
        'type' => 'GigabitEthernet',
        'mac' => 'AA:BB:CC:DD:EE:00',
        'mtu' => 1500,
        'state' => 'up',
        'link' => 'up',
        'connected' => true,
        'address' => '192.168.1.1',
        'mask' => '255.255.255.0',
        'gateway' => '192.168.1.254',
        'defaultgw' => true,
        'uptime' => 86400,
        'rxbytes' => 1_000_000,
        'txbytes' => 500_000,
        'rxpackets' => 1000,
        'txpackets' => 500,
        'last-change' => '2024-01-01T00:00:00Z',
        'speed' => 1000,
        'duplex' => 'full',
        'security-level' => 'public',
        'global' => true
      },
      'Bridge0' => {
        'description' => 'Home',
        'type' => 'bridge',
        'mac' => 'AA:BB:CC:DD:EE:01',
        'mtu' => 1500,
        'state' => 'up',
        'link' => 'up',
        'connected' => true,
        'address' => '192.168.0.1',
        'mask' => '255.255.255.0',
        'security-level' => 'private'
      }
    }
  end

  describe '#interfaces' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'returns normalized list of interfaces' do
      result = network.interfaces

      expect(result.size).to eq(2)
      expect(result.first[:id]).to eq('GigabitEthernet0')
      expect(result.first[:description]).to eq('WAN')
      expect(result.first[:defaultgw]).to be true
    end

    it 'normalizes kebab-case keys to snake_case' do
      result = network.interfaces

      expect(result.first[:last_change]).to eq('2024-01-01T00:00:00Z')
      expect(result.first[:security]).to eq('public')
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/interface')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty array' do
        expect(network.interfaces).to eq([])
      end
    end
  end

  describe '#interface' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'finds interface by ID' do
      result = network.interface('GigabitEthernet0')

      expect(result[:id]).to eq('GigabitEthernet0')
      expect(result[:description]).to eq('WAN')
    end

    it 'returns nil for unknown interface' do
      expect(network.interface('Unknown0')).to be_nil
    end
  end

  describe '#wan_status' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'returns interfaces with defaultgw flag' do
      result = network.wan_status

      expect(result.size).to eq(1)
      expect(result.first[:id]).to eq('GigabitEthernet0')
    end
  end

  describe '#lan_interfaces' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface')
        .to_return(status: 200, body: interface_response.to_json)
    end

    it 'returns bridge interfaces' do
      result = network.lan_interfaces

      expect(result.size).to eq(1)
      expect(result.first[:id]).to eq('Bridge0')
    end
  end

  describe '#statistics' do
    let(:stat_response) do
      {
        'GigabitEthernet0' => {
          'description' => 'WAN',
          'type' => 'GigabitEthernet',
          'mac' => 'AA:BB:CC:DD:EE:00',
          'mtu' => 1500,
          'state' => 'up',
          'link' => 'up',
          'connected' => true,
          'address' => '192.168.1.1',
          'mask' => '255.255.255.0',
          'uptime' => 86400,
          'rxbytes' => 1_000_000,
          'txbytes' => 500_000,
          'rxpackets' => 10000,
          'txpackets' => 5000,
          'rxerrors' => 5,
          'txerrors' => 2,
          'rxdrops' => 10,
          'txdrops' => 3,
          'collisions' => 0,
          'media' => '1000baseT',
          'speed' => 1000,
          'duplex' => 'full'
        },
        'Bridge0' => {
          'description' => 'Home',
          'type' => 'bridge',
          'rxbytes' => 2_000_000,
          'txbytes' => 1_000_000,
          'rxerrors' => 0,
          'txerrors' => 0,
          'rxdrops' => 0,
          'txdrops' => 0
        }
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface/stat')
        .to_return(status: 200, body: stat_response.to_json)
    end

    it 'returns interface statistics with error counts' do
      result = network.statistics

      expect(result.size).to eq(2)

      gige = result.find { |i| i[:id] == 'GigabitEthernet0' }
      expect(gige[:rxerrors]).to eq(5)
      expect(gige[:txerrors]).to eq(2)
      expect(gige[:rxdrops]).to eq(10)
      expect(gige[:txdrops]).to eq(3)
      expect(gige[:collisions]).to eq(0)
      expect(gige[:media]).to eq('1000baseT')
    end

    it 'includes traffic counters' do
      result = network.statistics
      gige = result.find { |i| i[:id] == 'GigabitEthernet0' }

      expect(gige[:rxbytes]).to eq(1_000_000)
      expect(gige[:txbytes]).to eq(500_000)
      expect(gige[:rxpackets]).to eq(10000)
      expect(gige[:txpackets]).to eq(5000)
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/interface/stat')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty array' do
        expect(network.statistics).to eq([])
      end
    end
  end

  describe '#interface_statistics' do
    let(:stat_response) do
      {
        'GigabitEthernet0' => {
          'description' => 'WAN',
          'rxerrors' => 5,
          'txerrors' => 2
        }
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/interface/stat')
        .to_return(status: 200, body: stat_response.to_json)
    end

    it 'finds statistics for specific interface' do
      result = network.interface_statistics('GigabitEthernet0')

      expect(result[:id]).to eq('GigabitEthernet0')
      expect(result[:rxerrors]).to eq(5)
    end

    it 'returns nil for unknown interface' do
      expect(network.interface_statistics('Unknown0')).to be_nil
    end
  end

  describe '#configure' do
    it 'sends enable command via batch' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'interface' => { 'GigabitEthernet0' => { 'up' => true } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      network.configure('GigabitEthernet0', up: true)

      expect(configure_stub).to have_been_requested
    end

    it 'sends disable command via batch' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'interface' => { 'WifiMaster0/AccessPoint1' => { 'up' => false } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      network.configure('WifiMaster0/AccessPoint1', up: false)

      expect(configure_stub).to have_been_requested
    end

    it 'handles additional options' do
      configure_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'interface' => { 'Bridge0' => { 'mtu' => 1400, 'up' => true } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      network.configure('Bridge0', up: true, mtu: 1400)

      expect(configure_stub).to have_been_requested
    end

    it 'returns empty hash when no parameters provided' do
      result = network.configure('GigabitEthernet0')
      expect(result).to eq({})
    end

    it 'returns API response on success' do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: '[{"interface": {"status": "ok"}}]')

      result = network.configure('GigabitEthernet0', up: true)

      expect(result).to be_an(Array)
    end
  end
end

