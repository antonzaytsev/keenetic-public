port = ENV.fetch('BACKEND_PORT', '4000')

bind "tcp://0.0.0.0:#{port}"
