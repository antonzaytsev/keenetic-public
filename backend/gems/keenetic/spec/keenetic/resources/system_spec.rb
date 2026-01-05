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
end

