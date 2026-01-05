require 'spec_helper'

RSpec.describe Keenetic::Resources::Policies do
  let(:client) { instance_double(Keenetic::Client) }
  let(:policies_resource) { described_class.new(client) }

  describe '#all' do
    context 'when policies exist' do
      let(:response) do
        [{
          'show' => {
            'sc' => {
              'ip' => {
                'policy' => {
                  'Policy0' => {
                    'description' => '!Latvia',
                    'permit' => [
                      { 'interface' => 'Wireguard1', 'enabled' => true },
                      { 'interface' => 'ISP', 'enabled' => false },
                      { 'interface' => 'Wireguard2', 'enabled' => true, 'no' => true }
                    ]
                  },
                  'Policy1' => {
                    'description' => '!Germany',
                    'permit' => [
                      { 'interface' => 'OpenVPN0', 'enabled' => true }
                    ]
                  }
                }
              }
            }
          }
        }]
      end

      before do
        allow(client).to receive(:batch).and_return(response)
      end

      it 'returns normalized policies' do
        result = policies_resource.all

        expect(result).to be_an(Array)
        expect(result.size).to eq(2)
      end

      it 'extracts policy name from description' do
        result = policies_resource.all

        latvia = result.find { |p| p[:id] == 'Policy0' }
        expect(latvia[:name]).to eq('Latvia')
        expect(latvia[:description]).to eq('!Latvia')
      end

      it 'filters only enabled interfaces without no flag' do
        result = policies_resource.all

        latvia = result.find { |p| p[:id] == 'Policy0' }
        expect(latvia[:interfaces]).to eq(['Wireguard1'])
        expect(latvia[:interface_count]).to eq(1)
      end
    end

    context 'when no policies exist' do
      before do
        allow(client).to receive(:batch).and_return([{}])
      end

      it 'returns empty array' do
        expect(policies_resource.all).to eq([])
      end
    end

    context 'when response is nil' do
      before do
        allow(client).to receive(:batch).and_return(nil)
      end

      it 'returns empty array' do
        expect(policies_resource.all).to eq([])
      end
    end
  end

  describe '#device_assignments' do
    context 'when devices have policies assigned' do
      let(:response) do
        [{
          'show' => {
            'sc' => {
              'ip' => {
                'hotspot' => {
                  'host' => [
                    { 'mac' => '00:11:22:33:44:55', 'policy' => 'Policy0' },
                    { 'mac' => 'AA:BB:CC:DD:EE:FF', 'policy' => 'Policy1' },
                    { 'mac' => '11:22:33:44:55:66' } # No policy
                  ]
                }
              }
            }
          }
        }]
      end

      before do
        allow(client).to receive(:batch).and_return(response)
      end

      it 'returns MAC to policy mapping' do
        result = policies_resource.device_assignments

        expect(result).to eq({
          '00:11:22:33:44:55' => 'Policy0',
          'aa:bb:cc:dd:ee:ff' => 'Policy1'
        })
      end
    end

    context 'when no devices have policies' do
      let(:response) do
        [{
          'show' => {
            'sc' => {
              'ip' => {
                'hotspot' => {
                  'host' => [
                    { 'mac' => '00:11:22:33:44:55' }
                  ]
                }
              }
            }
          }
        }]
      end

      before do
        allow(client).to receive(:batch).and_return(response)
      end

      it 'returns empty hash' do
        expect(policies_resource.device_assignments).to eq({})
      end
    end

    context 'when response is empty' do
      before do
        allow(client).to receive(:batch).and_return([{}])
      end

      it 'returns empty hash' do
        expect(policies_resource.device_assignments).to eq({})
      end
    end
  end

  describe '#find' do
    let(:policies_response) do
      [{
        'show' => {
          'sc' => {
            'ip' => {
              'policy' => {
                'Policy0' => {
                  'description' => '!Latvia',
                  'permit' => []
                }
              }
            }
          }
        }
      }]
    end

    before do
      allow(client).to receive(:batch).and_return(policies_response)
    end

    context 'when policy exists' do
      it 'returns the policy' do
        result = policies_resource.find(id: 'Policy0')

        expect(result[:id]).to eq('Policy0')
        expect(result[:name]).to eq('Latvia')
      end
    end

    context 'when policy does not exist' do
      it 'raises NotFoundError' do
        expect {
          policies_resource.find(id: 'NonExistent')
        }.to raise_error(Keenetic::NotFoundError, 'Policy NonExistent not found')
      end
    end
  end
end

