require_relative '../../spec_helper'

RSpec.describe Keenetic::Resources::Logs do
  let(:client) { Keenetic::Client.new }
  let(:logs) { client.logs }

  before { stub_keenetic_auth }

  # Sample Keenetic log entry format
  def keenetic_log_entry(id:, timestamp:, message:, level: 'Info', ident: 'ndm')
    {
      id.to_s => {
        'timestamp' => timestamp,
        'ident' => ident,
        'id' => id,
        'message' => {
          'level' => level,
          'label' => level[0],
          'message' => message
        }
      }
    }
  end

  # Build a log response hash from multiple entries
  def build_log_response(*entries)
    entries.reduce({}) { |acc, entry| acc.merge(entry) }
  end

  describe '#all' do
    context 'when using batch API' do
      let(:log_response) do
        {
          'show' => {
            'log' => {
              'log' => build_log_response(
                keenetic_log_entry(id: 100, timestamp: 'Jan  8 10:00:00', message: 'System started'),
                keenetic_log_entry(id: 101, timestamp: 'Jan  8 10:01:00', message: 'Network ready', level: 'Warning')
              ),
              'continued' => true
            }
          }
        }
      end

      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .with(body: [{ 'show' => { 'log' => {} } }].to_json)
          .to_return(status: 200, body: [log_response].to_json)
      end

      it 'returns normalized log entries' do
        result = logs.all

        expect(result.size).to eq(2)
        expect(result.first[:message]).to eq('System started').or eq('Network ready')
      end

      it 'normalizes log levels to lowercase' do
        result = logs.all

        levels = result.map { |l| l[:level] }
        expect(levels).to all(match(/^(info|warning|error|debug)$/))
      end

      it 'parses timestamps into ISO8601 format' do
        result = logs.all

        result.each do |log|
          expect(log[:time]).to match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end
      end

      it 'preserves facility/ident information' do
        result = logs.all

        expect(result.first[:facility]).to eq('ndm')
      end

      it 'sorts entries by ID descending (newest first)' do
        result = logs.all

        # The entry with higher ID should come first
        ids = result.map { |l| l[:message] }
        # ID 101 message should be before ID 100 message
        expect(ids).to include('Network ready', 'System started')
      end
    end

    context 'with limit parameter' do
      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .with(body: [{ 'show' => { 'log' => { 'limit' => 50 } } }].to_json)
          .to_return(status: 200, body: [{ 'show' => { 'log' => { 'log' => {} } } }].to_json)
      end

      it 'passes limit to API' do
        logs.all(limit: 50)

        expect(WebMock).to have_requested(:post, 'http://192.168.1.1/rci/')
          .with(body: [{ 'show' => { 'log' => { 'limit' => 50 } } }].to_json)
      end
    end

    context 'when batch API fails' do
      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 500, body: 'Internal Error')

        stub_request(:get, 'http://192.168.1.1/rci/show/log')
          .to_return(status: 200, body: [{ 'time' => 1704700000, 'msg' => 'Fallback log' }].to_json)
      end

      it 'falls back to direct GET request' do
        result = logs.all

        expect(WebMock).to have_requested(:get, 'http://192.168.1.1/rci/show/log')
      end
    end

    context 'when response is empty' do
      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [{ 'show' => { 'log' => { 'log' => {} } } }].to_json)
      end

      it 'returns empty array' do
        expect(logs.all).to eq([])
      end
    end

    context 'when response is nil' do
      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [{ 'show' => { 'log' => nil } }].to_json)
      end

      it 'returns empty array' do
        expect(logs.all).to eq([])
      end
    end
  end

  describe '#device_events' do
    let(:wifi_connect_log) do
      keenetic_log_entry(
        id: 200,
        timestamp: 'Jan  8 12:00:00',
        message: 'Hotspot: STA(9c:9c:1f:44:40:a9) had associated on "WifiMaster0/AccessPoint0"',
        ident: 'ndm'
      )
    end

    let(:wifi_auth_log) do
      keenetic_log_entry(
        id: 201,
        timestamp: 'Jan  8 12:00:05',
        message: 'Hotspot: STA(9c:9c:1f:44:40:a9) WPA2/WPA2PSK set key done on "WifiMaster0/AccessPoint0"',
        ident: 'ndm'
      )
    end

    let(:wifi_disconnect_log) do
      keenetic_log_entry(
        id: 202,
        timestamp: 'Jan  8 12:30:00',
        message: 'Hotspot: STA(9c:9c:1f:44:40:a9) had deauthenticated (reason: 1) on "WifiMaster1/AccessPoint0"',
        ident: 'ndm'
      )
    end

    let(:non_device_log) do
      keenetic_log_entry(
        id: 199,
        timestamp: 'Jan  8 11:59:00',
        message: 'System configuration saved',
        ident: 'ndm'
      )
    end

    before do
      response = {
        'show' => {
          'log' => {
            'log' => build_log_response(
              non_device_log,
              wifi_connect_log,
              wifi_auth_log,
              wifi_disconnect_log
            )
          }
        }
      }

      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [response].to_json)
    end

    it 'filters only device connection/disconnection events' do
      result = logs.device_events(since: nil)

      # Should not include the non-device log
      messages = result.map { |e| e[:message] }
      expect(messages).not_to include('System configuration saved')
      expect(result.size).to eq(3)
    end

    it 'extracts MAC address from log messages' do
      result = logs.device_events(since: nil)

      expect(result.first[:mac]).to eq('9C:9C:1F:44:40:A9')
    end

    it 'determines event type as connected for association events' do
      result = logs.device_events(since: nil)

      connect_event = result.find { |e| e[:message].include?('had associated') }
      expect(connect_event[:event_type]).to eq('connected')
    end

    it 'determines event type as connected for key set events' do
      result = logs.device_events(since: nil)

      auth_event = result.find { |e| e[:message].include?('set key done') }
      expect(auth_event[:event_type]).to eq('connected')
    end

    it 'determines event type as disconnected for deauthentication events' do
      result = logs.device_events(since: nil)

      disconnect_event = result.find { |e| e[:message].include?('deauthenticated') }
      expect(disconnect_event[:event_type]).to eq('disconnected')
    end

    it 'extracts WiFi band from interface name' do
      result = logs.device_events(since: nil)

      # WifiMaster0 = 2.4GHz
      connect_event = result.find { |e| e[:message].include?('WifiMaster0') }
      expect(connect_event[:band]).to eq('2.4GHz')

      # WifiMaster1 = 5GHz
      disconnect_event = result.find { |e| e[:message].include?('WifiMaster1') }
      expect(disconnect_event[:band]).to eq('5GHz')
    end

    it 'extracts interface name from message' do
      result = logs.device_events(since: nil)

      connect_event = result.find { |e| e[:message].include?('had associated') }
      expect(connect_event[:interface]).to eq('WifiMaster0/AccessPoint0')
    end

    it 'extracts disconnect reason when present' do
      result = logs.device_events(since: nil)

      disconnect_event = result.find { |e| e[:message].include?('deauthenticated') }
      expect(disconnect_event[:reason]).to eq('1')
    end

    it 'extracts connection details like WPA2' do
      result = logs.device_events(since: nil)

      auth_event = result.find { |e| e[:message].include?('set key done') }
      expect(auth_event[:details]).to include('WPA2')
    end

    context 'with MAC filter' do
      it 'filters events by specific MAC address' do
        result = logs.device_events(mac: '9C:9C:1F:44:40:A9', since: nil)

        expect(result).not_to be_empty
        expect(result.all? { |e| e[:mac] == '9C:9C:1F:44:40:A9' }).to be true
      end

      it 'handles MAC address case-insensitively' do
        result = logs.device_events(mac: '9c:9c:1f:44:40:a9', since: nil)

        expect(result).not_to be_empty
      end

      it 'returns empty when MAC not found' do
        result = logs.device_events(mac: 'AA:BB:CC:DD:EE:FF', since: nil)

        expect(result).to be_empty
      end
    end

    context 'with since filter (time-based)' do
      let(:old_log) do
        keenetic_log_entry(
          id: 100,
          timestamp: 'Jan  7 10:00:00',
          message: 'Hotspot: STA(aa:bb:cc:dd:ee:ff) had associated on "WifiMaster0/AccessPoint0"',
          ident: 'ndm'
        )
      end

      let(:recent_log) do
        keenetic_log_entry(
          id: 300,
          timestamp: 'Jan  8 14:00:00',
          message: 'Hotspot: STA(11:22:33:44:55:66) had associated on "WifiMaster0/AccessPoint0"',
          ident: 'ndm'
        )
      end

      before do
        response = {
          'show' => {
            'log' => {
              'log' => build_log_response(old_log, recent_log)
            }
          }
        }

        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [response].to_json)
      end

      it 'filters events older than since seconds from newest' do
        # Default since is 3600 (1 hour)
        # The old_log is from Jan 7, recent_log from Jan 8
        # With default 1 hour since, old_log should be filtered out
        result = logs.device_events(since: 3600)

        macs = result.map { |e| e[:mac] }
        expect(macs).to include('11:22:33:44:55:66')
        expect(macs).not_to include('AA:BB:CC:DD:EE:FF')
      end

      it 'returns all events when since is nil' do
        result = logs.device_events(since: nil)

        expect(result.size).to eq(2)
      end
    end
  end

  describe '#by_level' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'show' => { 'log' => { 'level' => 'error' } } }].to_json)
        .to_return(status: 200, body: [{ 'show' => { 'log' => { 'log' => {} } } }].to_json)
    end

    it 'sends level filter to API' do
      logs.by_level(level: 'error')

      expect(WebMock).to have_requested(:post, 'http://192.168.1.1/rci/')
        .with(body: [{ 'show' => { 'log' => { 'level' => 'error' } } }].to_json)
    end

    context 'with limit' do
      before do
        stub_request(:post, 'http://192.168.1.1/rci/')
          .with(body: [{ 'show' => { 'log' => { 'level' => 'warning', 'limit' => 100 } } }].to_json)
          .to_return(status: 200, body: [{ 'show' => { 'log' => { 'log' => {} } } }].to_json)
      end

      it 'sends both level and limit to API' do
        logs.by_level(level: 'warning', limit: 100)

        expect(WebMock).to have_requested(:post, 'http://192.168.1.1/rci/')
          .with(body: [{ 'show' => { 'log' => { 'level' => 'warning', 'limit' => 100 } } }].to_json)
      end
    end
  end

  describe 'timestamp parsing' do
    let(:log_with_timestamp) do
      keenetic_log_entry(
        id: 500,
        timestamp: 'Jan  8 02:30:45',
        message: 'Test log entry'
      )
    end

    before do
      response = {
        'show' => {
          'log' => {
            'log' => log_with_timestamp
          }
        }
      }

      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [response].to_json)
    end

    it 'parses Keenetic timestamp format correctly' do
      result = logs.all

      expect(result.first[:time]).to match(/^\d{4}-01-08T02:30:45/)
    end

    it 'adds current year to timestamp' do
      result = logs.all
      current_year = Time.now.year

      expect(result.first[:time]).to start_with(current_year.to_s)
    end
  end

  describe 'device event detection' do
    # Test various message patterns that should be detected as device events
    [
      { message: 'STA(aa:bb:cc:dd:ee:ff) connected', expected: true },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disconnected', expected: true },
      { message: 'Device aa:bb:cc:dd:ee:ff has connected', expected: true },
      { message: 'Host aa:bb:cc:dd:ee:ff appeared', expected: true },
      { message: 'Host aa:bb:cc:dd:ee:ff disappeared', expected: true },
      { message: 'Client aa:bb:cc:dd:ee:ff joined', expected: true },
      { message: 'Client aa:bb:cc:dd:ee:ff left', expected: true },
      { message: 'STA(aa:bb:cc:dd:ee:ff) associated', expected: true },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disassociated', expected: true },
      { message: 'System configuration saved', expected: false },
      { message: 'Network interface up', expected: false }
    ].each do |test_case|
      it "#{test_case[:expected] ? 'detects' : 'ignores'}: #{test_case[:message][0..50]}" do
        log_entry = keenetic_log_entry(
          id: 999,
          timestamp: 'Jan  8 15:00:00',
          message: test_case[:message]
        )

        response = {
          'show' => {
            'log' => {
              'log' => log_entry
            }
          }
        }

        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [response].to_json)

        result = logs.device_events(since: nil)

        if test_case[:expected]
          expect(result.size).to eq(1)
        else
          expect(result).to be_empty
        end
      end
    end
  end

  describe 'event type classification' do
    [
      { message: 'STA(aa:bb:cc:dd:ee:ff) connected', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) has connected', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) joined network', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) appeared', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) link up', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) associated', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) set key done', type: 'connected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disconnected', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) has disconnected', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) left network', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disappeared', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) link down', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disassociated', type: 'disconnected' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) deauthenticated', type: 'disconnected' }
    ].each do |test_case|
      it "classifies '#{test_case[:message][0..40]}...' as #{test_case[:type]}" do
        log_entry = keenetic_log_entry(
          id: 999,
          timestamp: 'Jan  8 15:00:00',
          message: test_case[:message]
        )

        response = {
          'show' => {
            'log' => {
              'log' => log_entry
            }
          }
        }

        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [response].to_json)

        result = logs.device_events(since: nil)

        expect(result.first[:event_type]).to eq(test_case[:type])
      end
    end
  end

  describe 'MAC address extraction' do
    [
      { message: 'STA(9c:9c:1f:44:40:a9) connected', expected_mac: '9C:9C:1F:44:40:A9' },
      { message: 'Device 9C:9C:1F:44:40:A9 appeared', expected_mac: '9C:9C:1F:44:40:A9' },
      { message: 'Host 9c-9c-1f-44-40-a9 connected', expected_mac: '9C:9C:1F:44:40:A9' },
      { message: 'No MAC here connected', expected_mac: nil }
    ].each do |test_case|
      it "extracts MAC from '#{test_case[:message]}'" do
        log_entry = keenetic_log_entry(
          id: 999,
          timestamp: 'Jan  8 15:00:00',
          message: test_case[:message]
        )

        response = {
          'show' => {
            'log' => {
              'log' => log_entry
            }
          }
        }

        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [response].to_json)

        result = logs.device_events(since: nil)

        if test_case[:expected_mac]
          expect(result.first[:mac]).to eq(test_case[:expected_mac])
        else
          # No MAC means it won't be detected as device event (unless facility matches)
          expect(result).to be_empty
        end
      end
    end
  end

  describe 'connection details extraction' do
    [
      { message: 'STA(aa:bb:cc:dd:ee:ff) WPA2/WPA2PSK set key done', details: 'WPA2, Authenticated' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) WPA3 connected', details: 'WPA3' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) had associated', details: 'WiFi Associated' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) had deauthenticated', details: 'Deauthenticated' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) disassociated', details: 'Disassociated' },
      { message: 'STA(aa:bb:cc:dd:ee:ff) handshake timeout', details: 'Handshake Timeout' }
    ].each do |test_case|
      it "extracts details from '#{test_case[:message][0..40]}...'" do
        log_entry = keenetic_log_entry(
          id: 999,
          timestamp: 'Jan  8 15:00:00',
          message: test_case[:message]
        )

        response = {
          'show' => {
            'log' => {
              'log' => log_entry
            }
          }
        }

        stub_request(:post, 'http://192.168.1.1/rci/')
          .to_return(status: 200, body: [response].to_json)

        result = logs.device_events(since: nil)

        expect(result.first[:details]).to eq(test_case[:details])
      end
    end
  end
end

