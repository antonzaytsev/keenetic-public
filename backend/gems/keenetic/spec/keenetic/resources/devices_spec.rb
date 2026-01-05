require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Devices do
  let(:client) { Keenetic::Client.new }
  let(:devices) { client.devices }

  before { stub_keenetic_auth }

  # Helper to stub both required endpoints for devices.all
  def stub_devices_endpoints(hosts_response, associations_response = { 'station' => [] })
    stub_request(:get, 'http://192.168.1.1/rci/show/ip/hotspot/host')
      .to_return(status: 200, body: hosts_response.to_json)
    stub_request(:get, 'http://192.168.1.1/rci/show/associations')
      .to_return(status: 200, body: associations_response.to_json)
  end

  describe '#all' do
    let(:hotspot_response) do
      [
        {
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'name' => 'My Phone',
          'hostname' => 'iphone',
          'ip' => '192.168.1.100',
          'interface' => 'Bridge0',
          'active' => true,
          'registered' => true,
          'rxbytes' => 1_000_000,
          'txbytes' => 500_000
        },
        {
          'mac' => '11:22:33:44:55:66',
          'hostname' => 'laptop',
          'ip' => '192.168.1.101',
          'interface' => 'Bridge0',
          'active' => false,
          'registered' => true
        }
      ]
    end

    before do
      stub_devices_endpoints(hotspot_response)
    end

    it 'returns normalized list of devices' do
      result = devices.all

      expect(result.size).to eq(2)
      expect(result.first[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result.first[:name]).to eq('My Phone')
      expect(result.first[:ip]).to eq('192.168.1.100')
      expect(result.first[:active]).to be true
    end

    it 'uses hostname as name fallback' do
      result = devices.all
      expect(result.last[:name]).to eq('laptop')
    end

    context 'when response has single host (not array)' do
      before do
        stub_devices_endpoints({ 'host' => { 'mac' => 'AA:BB:CC:DD:EE:FF', 'name' => 'Single Device' } })
      end

      it 'handles single device response' do
        result = devices.all
        expect(result.size).to eq(1)
        expect(result.first[:name]).to eq('Single Device')
      end
    end

    context 'when response is empty' do
      before do
        stub_devices_endpoints(nil)
      end

      it 'returns empty array' do
        expect(devices.all).to eq([])
      end
    end
  end

  describe '#find' do
    before do
      stub_devices_endpoints([
        { 'mac' => 'AA:BB:CC:DD:EE:FF', 'name' => 'Device 1' },
        { 'mac' => '11:22:33:44:55:66', 'name' => 'Device 2' }
      ])
    end

    it 'finds device by MAC address' do
      device = devices.find(mac: 'AA:BB:CC:DD:EE:FF')
      expect(device[:name]).to eq('Device 1')
    end

    it 'finds device case-insensitively' do
      device = devices.find(mac: 'aa:bb:cc:dd:ee:ff')
      expect(device[:name]).to eq('Device 1')
    end

    it 'raises NotFoundError when device not found' do
      expect { devices.find(mac: 'XX:XX:XX:XX:XX:XX') }
        .to raise_error(Keenetic::NotFoundError, /not found/)
    end
  end

  describe '#update' do
    it 'sends name update via known.host' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'known' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'name' => 'New Name' } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.update(mac: 'AA:BB:CC:DD:EE:FF', name: 'New Name')

      expect(update_stub).to have_been_requested
    end

    it 'sends permit access via ip.hotspot.host' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'ip' => { 'hotspot' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'permit' => true } } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.update(mac: 'AA:BB:CC:DD:EE:FF', access: 'permit')

      expect(update_stub).to have_been_requested
    end

    it 'sends deny access via ip.hotspot.host' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'ip' => { 'hotspot' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'deny' => true } } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.update(mac: 'AA:BB:CC:DD:EE:FF', access: 'deny')

      expect(update_stub).to have_been_requested
    end

    it 'sends name and access as separate commands' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [
          { 'known' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'name' => 'Test' } } },
          { 'ip' => { 'hotspot' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'deny' => true, 'schedule' => 'night' } } } }
        ].to_json)
        .to_return(status: 200, body: '[{},{}]')

      devices.update(mac: 'AA:BB:CC:DD:EE:FF', name: 'Test', access: 'deny', schedule: 'night')

      expect(update_stub).to have_been_requested
    end

    it 'normalizes MAC to lowercase' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'known' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'name' => 'Test' } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.update(mac: 'AA:BB:CC:DD:EE:FF', name: 'Test')

      expect(update_stub).to have_been_requested
    end

    it 'returns empty hash when no attributes provided' do
      result = devices.update(mac: 'AA:BB:CC:DD:EE:FF')
      expect(result).to eq({})
    end
  end

  describe '#active' do
    before do
      stub_devices_endpoints([
        { 'mac' => 'AA:BB:CC:DD:EE:FF', 'name' => 'Active', 'active' => true },
        { 'mac' => '11:22:33:44:55:66', 'name' => 'Inactive', 'active' => false }
      ])
    end

    it 'returns only active devices' do
      result = devices.active
      expect(result.size).to eq(1)
      expect(result.first[:name]).to eq('Active')
    end
  end

  describe '#delete' do
    it 'sends delete request as array with mac and no flag' do
      delete_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'ip' => { 'hotspot' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'no' => true } } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.delete(mac: 'AA:BB:CC:DD:EE:FF')

      expect(delete_stub).to have_been_requested
    end

    it 'normalizes MAC address to lowercase' do
      delete_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'ip' => { 'hotspot' => { 'host' => { 'mac' => 'aa:bb:cc:dd:ee:ff', 'no' => true } } } }].to_json)
        .to_return(status: 200, body: '[{}]')

      devices.delete(mac: 'AA:BB:CC:DD:EE:FF')

      expect(delete_stub).to have_been_requested
    end

    it 'returns API response array' do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: '[{}]')

      result = devices.delete(mac: 'AA:BB:CC:DD:EE:FF')

      expect(result).to eq([{}])
    end
  end
end

