# frozen_string_literal: true

require 'net/http'
require 'json'
require 'fileutils'

# Reboots the router daily at 5:00 AM after creating a config backup.
#
# Optional env vars:
#   BACKEND_URL                 — base URL of the backend service (default: http://backend:4000)
#   BACKUP_CONFIG_DIR           — directory to store pre-reboot backups (default: /app/backups)

class DailyRebootJob < BaseJob
  BACKEND_URL = ENV.fetch('BACKEND_URL', 'http://backend:4000')
  BACKUP_DIR  = ENV.fetch('BACKUP_CONFIG_DIR', '/app/backups')

  def self.schedule(scheduler)
    scheduler.cron('0 5 * * *') { new.run }
    log.info('Scheduled daily reboot at 5:00 AM')
  end

  def run
    log.info('Daily reboot — backing up config and rebooting')
    backup_config
    reboot_router
  rescue => e
    log.error("Daily reboot failed: #{e.class}: #{e.message}")
  end

  private

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
