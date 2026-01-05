# frozen_string_literal: true

require_relative 'lib/keenetic/version'

Gem::Specification.new do |spec|
  spec.name = 'keenetic'
  spec.version = Keenetic::VERSION
  spec.authors = ['Anton']
  spec.summary = 'Ruby client for Keenetic router API'
  spec.description = 'A Ruby client for interacting with Keenetic router REST API. Supports authentication, device management, system monitoring, and network interfaces.'
  spec.homepage = 'https://github.com/example/keenetic'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.files = Dir.chdir(__dir__) do
    Dir['{lib}/**/*', 'LICENSE.txt', 'README.md']
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'typhoeus', '~> 1.4'

  spec.metadata['rubygems_mfa_required'] = 'true'
end

