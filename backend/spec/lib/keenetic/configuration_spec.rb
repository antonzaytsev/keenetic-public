require 'spec_helper'

RSpec.describe Keenetic::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.host).to eq('192.168.1.1')
      expect(config.login).to eq('admin')
      expect(config.timeout).to eq(30)
      expect(config.open_timeout).to eq(10)
    end

    it 'reads from environment variables' do
      allow(ENV).to receive(:fetch).with('KEENETIC_HOST', '192.168.1.1').and_return('10.0.0.1')
      allow(ENV).to receive(:fetch).with('KEENETIC_LOGIN', 'admin').and_return('user')
      allow(ENV).to receive(:fetch).with('KEENETIC_PASSWORD', '').and_return('secret')

      new_config = described_class.new
      expect(new_config.host).to eq('10.0.0.1')
      expect(new_config.login).to eq('user')
      expect(new_config.password).to eq('secret')
    end
  end

  describe '#base_url' do
    it 'returns http url with host' do
      config.host = '10.0.0.1'
      expect(config.base_url).to eq('http://10.0.0.1')
    end
  end

  describe '#validate!' do
    context 'when configuration is valid' do
      before do
        config.host = '192.168.1.1'
        config.login = 'admin'
        config.password = 'secret'
      end

      it 'does not raise error' do
        expect { config.validate! }.not_to raise_error
      end
    end

    context 'when host is missing' do
      before { config.host = nil }

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Keenetic::ConfigurationError, 'Host is required')
      end
    end

    context 'when login is missing' do
      before do
        config.host = '192.168.1.1'
        config.login = ''
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Keenetic::ConfigurationError, 'Login is required')
      end
    end

    context 'when password is missing' do
      before do
        config.host = '192.168.1.1'
        config.login = 'admin'
        config.password = nil
      end

      it 'raises ConfigurationError' do
        expect { config.validate! }.to raise_error(Keenetic::ConfigurationError, 'Password is required')
      end
    end
  end
end

RSpec.describe Keenetic do
  describe '.configure' do
    it 'yields configuration object' do
      Keenetic.configure do |config|
        config.host = '10.0.0.1'
        config.login = 'test_user'
        config.password = 'test_pass'
      end

      expect(Keenetic.configuration.host).to eq('10.0.0.1')
      expect(Keenetic.configuration.login).to eq('test_user')
      expect(Keenetic.configuration.password).to eq('test_pass')
    end
  end

  describe '.reset_configuration!' do
    it 'resets configuration to defaults' do
      Keenetic.configure { |c| c.host = '10.0.0.1' }
      Keenetic.reset_configuration!

      expect(Keenetic.configuration.host).to eq('192.168.1.1')
    end
  end
end

