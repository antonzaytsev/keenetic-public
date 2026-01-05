require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::System do
  let(:client) { Keenetic::Client.new }
  let(:system_resource) { client.system }

  before { stub_keenetic_auth }

  describe '#resources' do
    let(:system_response) do
      {
        'cpuload' => 15,
        'memtotal' => 262_144,
        'memfree' => 131_072,
        'membuffers' => 16_384,
        'memcache' => 32_768,
        'swaptotal' => 524_288,
        'swapfree' => 500_000,
        'uptime' => 86400
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/system')
        .to_return(status: 200, body: system_response.to_json)
    end

    it 'returns normalized system resources' do
      result = system_resource.resources

      expect(result[:cpu][:load_percent]).to eq(15)
      expect(result[:memory][:total]).to eq(262_144)
      expect(result[:memory][:free]).to eq(131_072)
      expect(result[:memory][:used]).to eq(81_920) # total - free - buffers - cached
      expect(result[:memory][:used_percent]).to be_within(0.5).of(31.2)
      expect(result[:uptime]).to eq(86400)
    end

    it 'calculates swap usage' do
      result = system_resource.resources

      expect(result[:swap][:total]).to eq(524_288)
      expect(result[:swap][:used]).to eq(24_288)
      expect(result[:swap][:used_percent]).to be_within(0.1).of(4.6)
    end

    context 'when swap is not available' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/system')
          .to_return(status: 200, body: {
            'cpuload' => 10,
            'memtotal' => 100_000,
            'memfree' => 50_000,
            'swaptotal' => 0,
            'swapfree' => 0
          }.to_json)
      end

      it 'returns nil for swap' do
        result = system_resource.resources
        expect(result[:swap]).to be_nil
      end
    end
  end

  describe '#info' do
    let(:version_response) do
      {
        'model' => 'Keenetic Giga',
        'device' => 'KN-1010',
        'manufacturer' => 'Keenetic Ltd.',
        'vendor' => 'Keenetic',
        'hw_version' => 'A',
        'hw_id' => 'KN-1010',
        'title' => 'KeeneticOS',
        'release' => '4.1.0.0.C.0',
        'ndm' => {
          'exact' => '4.1.0.0-0',
          'version' => '4.1'
        },
        'arch' => 'mips',
        'ndw' => {
          'version' => '4.1.0.0'
        },
        'components' => ['base', 'wifi'],
        'sandbox' => 'keenetic'
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/version')
        .to_return(status: 200, body: version_response.to_json)
    end

    it 'returns normalized system info' do
      result = system_resource.info

      expect(result[:model]).to eq('Keenetic Giga')
      expect(result[:device]).to eq('KN-1010')
      expect(result[:manufacturer]).to eq('Keenetic Ltd.')
      expect(result[:firmware]).to eq('KeeneticOS')
      expect(result[:firmware_version]).to eq('4.1.0.0.C.0')
      expect(result[:ndm_version]).to eq('4.1.0.0-0')
      expect(result[:arch]).to eq('mips')
    end
  end

  describe '#uptime' do
    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/system')
        .to_return(status: 200, body: { 'uptime' => 123456 }.to_json)
    end

    it 'returns system uptime' do
      expect(system_resource.uptime).to eq(123456)
    end
  end

  describe '#defaults' do
    let(:defaults_response) do
      {
        'system-name' => 'Keenetic',
        'domain-name' => 'local',
        'language' => 'en',
        'ntp-server' => 'pool.ntp.org',
        'auto-update' => true,
        'led-mode' => 'auto'
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/defaults')
        .to_return(status: 200, body: defaults_response.to_json)
    end

    it 'returns normalized default settings' do
      result = system_resource.defaults

      expect(result[:system_name]).to eq('Keenetic')
      expect(result[:domain_name]).to eq('local')
      expect(result[:language]).to eq('en')
      expect(result[:ntp_server]).to eq('pool.ntp.org')
      expect(result[:auto_update]).to be true
      expect(result[:led_mode]).to eq('auto')
    end

    it 'converts kebab-case keys to snake_case' do
      result = system_resource.defaults

      expect(result.keys).to all(be_a(Symbol))
      expect(result.keys).not_to include(:system_name.to_s.tr('_', '-'))
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/defaults')
          .to_return(status: 200, body: '{}')
      end

      it 'returns empty hash' do
        expect(system_resource.defaults).to eq({})
      end
    end

    context 'when response has nested values' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/defaults')
          .to_return(status: 200, body: {
            'network-settings' => {
              'default-gateway' => '192.168.1.1',
              'dns-server' => '8.8.8.8'
            }
          }.to_json)
      end

      it 'normalizes nested keys' do
        result = system_resource.defaults

        expect(result[:network_settings]).to be_a(Hash)
        expect(result[:network_settings][:default_gateway]).to eq('192.168.1.1')
        expect(result[:network_settings][:dns_server]).to eq('8.8.8.8')
      end
    end
  end

  describe '#license' do
    let(:license_response) do
      {
        'valid' => true,
        'active' => 'true',
        'expires' => '2025-12-31',
        'type' => 'standard',
        'features' => [
          { 'name' => 'vpn-server', 'enabled' => true },
          { 'name' => 'parental-control', 'enabled' => 'true' }
        ],
        'services' => [
          { 'name' => 'keendns', 'enabled' => true, 'active' => 'true' },
          { 'name' => 'safedns', 'enabled' => false }
        ]
      }
    end

    before do
      stub_request(:get, 'http://192.168.1.1/rci/show/license')
        .to_return(status: 200, body: license_response.to_json)
    end

    it 'returns normalized license info' do
      result = system_resource.license

      expect(result[:valid]).to be true
      expect(result[:active]).to be true
      expect(result[:expires]).to eq('2025-12-31')
      expect(result[:type]).to eq('standard')
    end

    it 'normalizes features array' do
      result = system_resource.license

      expect(result[:features]).to be_an(Array)
      expect(result[:features].size).to eq(2)
      expect(result[:features][0][:name]).to eq('vpn-server')
      expect(result[:features][0][:enabled]).to be true
    end

    it 'normalizes services with boolean values' do
      result = system_resource.license

      expect(result[:services]).to be_an(Array)
      expect(result[:services][0][:name]).to eq('keendns')
      expect(result[:services][0][:enabled]).to be true
      expect(result[:services][0][:active]).to be true
      expect(result[:services][1][:enabled]).to be false
    end

    it 'handles string boolean values' do
      result = system_resource.license

      # 'true' string should be converted to boolean true
      expect(result[:active]).to be true
      expect(result[:services][0][:active]).to be true
    end

    context 'when license is not valid' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/license')
          .to_return(status: 200, body: {
            'valid' => false,
            'active' => false
          }.to_json)
      end

      it 'returns invalid license info' do
        result = system_resource.license

        expect(result[:valid]).to be false
        expect(result[:active]).to be false
      end
    end

    context 'when response is empty' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/license')
          .to_return(status: 200, body: '{}')
      end

      it 'returns hash with empty arrays for features and services' do
        result = system_resource.license
        expect(result[:features]).to eq([])
        expect(result[:services]).to eq([])
      end
    end

    context 'when features is nil or missing' do
      before do
        stub_request(:get, 'http://192.168.1.1/rci/show/license')
          .to_return(status: 200, body: {
            'valid' => true,
            'type' => 'basic'
          }.to_json)
      end

      it 'returns empty features array' do
        result = system_resource.license

        expect(result[:valid]).to be true
        expect(result[:features]).to eq([])
        expect(result[:services]).to eq([])
      end
    end
  end
end

