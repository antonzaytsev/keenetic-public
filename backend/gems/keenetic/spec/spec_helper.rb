require 'webmock/rspec'
require 'keenetic'

WebMock.disable_net_connect!(allow_localhost: false)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  config.before(:each) do
    Keenetic.reset_configuration!
    Keenetic.configure do |c|
      c.host = '192.168.1.1'
      c.login = 'admin'
      c.password = 'test_password'
    end
  end
end

# Helper to stub Keenetic authentication
def stub_keenetic_auth(host: '192.168.1.1')
  # First request - get challenge
  stub_request(:get, "http://#{host}/auth")
    .to_return(
      status: 401,
      headers: {
        'X-NDM-Challenge' => 'test_challenge_123',
        'X-NDM-Realm' => 'KEENETIC_REALM',
        'Set-Cookie' => 'ndm_session=test_session_id; path=/'
      }
    )

  # Second request - auth with hash
  stub_request(:post, "http://#{host}/auth")
    .to_return(
      status: 200,
      headers: {
        'Set-Cookie' => 'ndm_session=authenticated_session; path=/'
      },
      body: '{"authenticated": true}'
    )
end

