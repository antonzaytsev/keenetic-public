require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::DHCP do
  let(:client) { Keenetic::Client.new }
  let(:dhcp) { client.dhcp }

  before { stub_keenetic_auth }

  describe '#leases' do
    let(:lease_response) do
      [
        {
          'ip' => '192.168.1.100',
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'hostname' => 'iphone',
          'expires' => 1704067200
        },
        {
          'ip' => '192.168.1.101',
          'mac' => '11:22:33:44:55:66',
          'hostname' => 'laptop',
          'expires' => 1704153600
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/lease')
        .to_return(status: 200, body: lease_response.to_json)
    end

    it 'returns normalized list of leases' do
      result = dhcp.leases

      expect(result.size).to eq(2)
      expect(result.first[:ip]).to eq('192.168.1.100')
      expect(result.first[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result.first[:hostname]).to eq('iphone')
      expect(result.first[:expires]).to eq(1704067200)
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/lease')
          .to_return(status: 200, body: '[]')
      end

      it 'returns empty array' do
        expect(dhcp.leases).to eq([])
      end
    end

    context 'when response is not an array' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/lease')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty array' do
        expect(dhcp.leases).to eq([])
      end
    end
  end

  describe '#bindings' do
    let(:binding_response) do
      [
        {
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'ip' => '192.168.1.100',
          'name' => 'My Server'
        },
        {
          'mac' => '11:22:33:44:55:66',
          'ip' => '192.168.1.101',
          'name' => 'NAS'
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/binding')
        .to_return(status: 200, body: binding_response.to_json)
    end

    it 'returns normalized list of bindings' do
      result = dhcp.bindings

      expect(result.size).to eq(2)
      expect(result.first[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result.first[:ip]).to eq('192.168.1.100')
      expect(result.first[:name]).to eq('My Server')
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/binding')
          .to_return(status: 200, body: '[]')
      end

      it 'returns empty array' do
        expect(dhcp.bindings).to eq([])
      end
    end
  end

  describe '#find_binding' do
    let(:binding_response) do
      [
        {
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'ip' => '192.168.1.100',
          'name' => 'My Server'
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/dhcp/binding')
        .to_return(status: 200, body: binding_response.to_json)
    end

    it 'finds binding by MAC address' do
      result = dhcp.find_binding(mac: 'AA:BB:CC:DD:EE:FF')

      expect(result[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result[:ip]).to eq('192.168.1.100')
    end

    it 'finds binding with case-insensitive MAC' do
      result = dhcp.find_binding(mac: 'aa:bb:cc:dd:ee:ff')

      expect(result[:mac]).to eq('AA:BB:CC:DD:EE:FF')
    end

    it 'returns nil for unknown MAC' do
      expect(dhcp.find_binding(mac: '00:00:00:00:00:00')).to be_nil
    end
  end

  describe '#create_binding' do
    it 'sends create command via batch with all parameters' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'ip' => '192.168.1.100',
                'name' => 'My Server'
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.create_binding(mac: 'AA:BB:CC:DD:EE:FF', ip: '192.168.1.100', name: 'My Server')

      expect(create_stub).to have_been_requested
    end

    it 'sends create command without name when not provided' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'ip' => '192.168.1.100'
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.create_binding(mac: 'AA:BB:CC:DD:EE:FF', ip: '192.168.1.100')

      expect(create_stub).to have_been_requested
    end

    it 'normalizes MAC to uppercase' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'ip' => '192.168.1.100'
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.create_binding(mac: 'aa:bb:cc:dd:ee:ff', ip: '192.168.1.100')

      expect(create_stub).to have_been_requested
    end
  end

  describe '#update_binding' do
    it 'sends update command with IP' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'ip' => '192.168.1.101'
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.update_binding(mac: 'AA:BB:CC:DD:EE:FF', ip: '192.168.1.101')

      expect(update_stub).to have_been_requested
    end

    it 'sends update command with name' do
      update_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'name' => 'New Name'
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.update_binding(mac: 'AA:BB:CC:DD:EE:FF', name: 'New Name')

      expect(update_stub).to have_been_requested
    end

    it 'returns empty hash when no update params provided' do
      result = dhcp.update_binding(mac: 'AA:BB:CC:DD:EE:FF')
      expect(result).to eq({})
    end
  end

  describe '#delete_binding' do
    it 'sends delete command via batch' do
      delete_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'no' => true
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.delete_binding(mac: 'AA:BB:CC:DD:EE:FF')

      expect(delete_stub).to have_been_requested
    end

    it 'normalizes MAC to uppercase' do
      delete_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'dhcp' => {
              'host' => {
                'mac' => 'AA:BB:CC:DD:EE:FF',
                'no' => true
              }
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      dhcp.delete_binding(mac: 'aa:bb:cc:dd:ee:ff')

      expect(delete_stub).to have_been_requested
    end
  end
end

