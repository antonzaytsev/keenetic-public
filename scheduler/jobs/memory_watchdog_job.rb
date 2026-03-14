# frozen_string_literal: true

require 'net/http'
require 'json'
require 'fileutils'

# Checks router memory usage every hour between 3:00–8:00 AM local time.
# If used_percent exceeds the threshold (default 90%), creates a config backup
# and reboots the router.
#
# Optional env vars:
#   MEMORY_WATCHDOG_THRESHOLD   — percent threshold to trigger reboot (default: 90)
#   BACKEND_URL                 — base URL of the backend service (default: http://backend:4000)
#   BACKUP_CONFIG_DIR           — directory to store pre-reboot backups (default: /app/backups)

class MemoryWatchdogJob < BaseJob
  BACKEND_URL = ENV.fetch('BACKEND_URL', 'http://backend:4000')
  BACKUP_DIR  = ENV.fetch('BACKUP_CONFIG_DIR', '/app/backups')
  THRESHOLD   = ENV.fetch('MEMORY_WATCHDOG_THRESHOLD', '90').to_i

  WATCH_HOURS = (3..8).to_a.freeze

  def self.schedule(scheduler)
    scheduler.cron('0 3-8 * * *') { new.run }
    log.info("Scheduled hourly memory check at #{WATCH_HOURS.first}:00–#{WATCH_HOURS.last}:00 (threshold: #{THRESHOLD}%)")
  end

  def run
    memory = fetch_memory
    used = memory['used_percent']
    log.info("Memory usage: #{used}%")

    if used > THRESHOLD
      log.warn("Memory #{used}% exceeds #{THRESHOLD}% — backing up and rebooting")
      backup_config
      reboot_router
    else
      log.info("Memory OK (#{used}% <= #{THRESHOLD}%)")
    end
  rescue => e
    log.error("Memory watchdog failed: #{e.class}: #{e.message}")
  end

  private

  def fetch_memory
    uri = URI("#{BACKEND_URL}/api/system/resources")
    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.get(uri.request_uri)
    end

    raise "Backend returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data.dig('resources', 'memory') || raise('No memory data in response')
  end

  def backup_config
    log.info('Creating pre-reboot config backup')
    uri = URI("#{BACKEND_URL}/api/system/config")
    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.open_timeout = 10
      http.read_timeout = 60
      http.get(uri.request_uri)
    end

    raise "Config download failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    FileUtils.mkdir_p(BACKUP_DIR)
    filename = "keenetic-config-prereboot-#{Time.now.strftime('%Y%m%d-%H%M%S')}.txt"
    path = File.join(BACKUP_DIR, filename)
    File.write(path, response.body)
    log.info("Backup saved: #{path} (#{response.body.bytesize} bytes)")
  end

  def reboot_router
    log.info('Sending reboot request')
    uri = URI("#{BACKEND_URL}/api/system/reboot")
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    raise "Reboot request failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    log.info('Router reboot initiated')
  end
end
