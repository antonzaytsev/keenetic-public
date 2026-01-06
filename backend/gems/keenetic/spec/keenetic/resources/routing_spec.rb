require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Routing do
  let(:client) { Keenetic::Client.new }
  let(:routing) { client.routing }

  before { stub_keenetic_auth }

  describe '#routes' do
    let(:routes_response) do
      [
        {
          'destination' => '0.0.0.0',
          'mask' => '0.0.0.0',
          'gateway' => '192.168.1.1',
          'interface' => 'ISP',
          'metric' => 0,
          'flags' => 'G',
          'auto' => true
        },
        {
          'destination' => '192.168.1.0',
          'mask' => '255.255.255.0',
          'gateway' => nil,
          'interface' => 'Bridge0',
          'metric' => 0,
          'flags' => 'U',
          'auto' => true
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/route')
        .to_return(status: 200, body: routes_response.to_json)
    end

    it 'returns normalized list of routes' do
      result = routing.routes

      expect(result.size).to eq(2)
      expect(result.first[:destination]).to eq('0.0.0.0')
      expect(result.first[:mask]).to eq('0.0.0.0')
      expect(result.first[:gateway]).to eq('192.168.1.1')
      expect(result.first[:interface]).to eq('ISP')
      expect(result.first[:metric]).to eq(0)
      expect(result.first[:flags]).to eq('G')
      expect(result.first[:auto]).to eq(true)
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/route')
          .to_return(status: 200, body: '[]')
      end

      it 'returns empty array' do
        expect(routing.routes).to eq([])
      end
    end

    context 'when response is not an array' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/route')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty array' do
        expect(routing.routes).to eq([])
      end
    end
  end

  describe '#arp_table' do
    let(:arp_response) do
      [
        {
          'ip' => '192.168.1.100',
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'interface' => 'Bridge0',
          'state' => 'reachable'
        },
        {
          'ip' => '192.168.1.101',
          'mac' => '11:22:33:44:55:66',
          'interface' => 'Bridge0',
          'state' => 'stale'
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/arp')
        .to_return(status: 200, body: arp_response.to_json)
    end

    it 'returns normalized list of ARP entries' do
      result = routing.arp_table

      expect(result.size).to eq(2)
      expect(result.first[:ip]).to eq('192.168.1.100')
      expect(result.first[:mac]).to eq('AA:BB:CC:DD:EE:FF')
      expect(result.first[:interface]).to eq('Bridge0')
      expect(result.first[:state]).to eq('reachable')
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/ip/arp')
          .to_return(status: 200, body: '[]')
      end

      it 'returns empty array' do
        expect(routing.arp_table).to eq([])
      end
    end
  end

  describe '#find_route' do
    let(:routes_response) do
      [
        {
          'destination' => '10.0.0.0',
          'mask' => '255.0.0.0',
          'gateway' => '192.168.1.1',
          'interface' => 'ISP',
          'metric' => 10,
          'flags' => 'UG',
          'auto' => false
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/route')
        .to_return(status: 200, body: routes_response.to_json)
    end

    it 'finds route by destination and mask' do
      result = routing.find_route(destination: '10.0.0.0', mask: '255.0.0.0')

      expect(result[:destination]).to eq('10.0.0.0')
      expect(result[:gateway]).to eq('192.168.1.1')
    end

    it 'returns nil for unknown route' do
      expect(routing.find_route(destination: '172.16.0.0', mask: '255.240.0.0')).to be_nil
    end
  end

  describe '#find_arp_entry' do
    let(:arp_response) do
      [
        {
          'ip' => '192.168.1.100',
          'mac' => 'AA:BB:CC:DD:EE:FF',
          'interface' => 'Bridge0',
          'state' => 'reachable'
        }
      ]
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/ip/arp')
        .to_return(status: 200, body: arp_response.to_json)
    end

    it 'finds ARP entry by IP' do
      result = routing.find_arp_entry(ip: '192.168.1.100')

      expect(result[:ip]).to eq('192.168.1.100')
      expect(result[:mac]).to eq('AA:BB:CC:DD:EE:FF')
    end

    it 'returns nil for unknown IP' do
      expect(routing.find_arp_entry(ip: '192.168.1.200')).to be_nil
    end
  end

  describe '#create_route' do
    it 'sends create command via batch with gateway' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'route' => {
              'destination' => '10.0.0.0',
              'mask' => '255.0.0.0',
              'gateway' => '192.168.1.1'
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      routing.create_route(destination: '10.0.0.0', mask: '255.0.0.0', gateway: '192.168.1.1')

      expect(create_stub).to have_been_requested
    end

    it 'sends create command via batch with interface' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'route' => {
              'destination' => '10.0.0.0',
              'mask' => '255.0.0.0',
              'interface' => 'ISP'
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      routing.create_route(destination: '10.0.0.0', mask: '255.0.0.0', interface: 'ISP')

      expect(create_stub).to have_been_requested
    end

    it 'sends create command with all parameters' do
      create_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'route' => {
              'destination' => '10.0.0.0',
              'mask' => '255.0.0.0',
              'gateway' => '192.168.1.1',
              'interface' => 'ISP',
              'metric' => 100
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      routing.create_route(
        destination: '10.0.0.0',
        mask: '255.0.0.0',
        gateway: '192.168.1.1',
        interface: 'ISP',
        metric: 100
      )

      expect(create_stub).to have_been_requested
    end
  end

  describe '#delete_route' do
    it 'sends delete command via batch' do
      delete_stub = stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{
          'ip' => {
            'route' => {
              'destination' => '10.0.0.0',
              'mask' => '255.0.0.0',
              'no' => true
            }
          }
        }].to_json)
        .to_return(status: 200, body: '[{}]')

      routing.delete_route(destination: '10.0.0.0', mask: '255.0.0.0')

      expect(delete_stub).to have_been_requested
    end
  end
end

