# frozen_string_literal: true

require 'net/http'
require 'fileutils'

# Fetches the router configuration backup from the backend API and saves it
# to a local directory, keeping the 10 most recent files.
#
# Required env vars:
#   BACKUP_CONFIG_DIR           — host-mounted directory to store backups (default: /app/backups)
#
# Optional env vars:
#   BACKUP_CONFIG_TIME          — daily run time in HH:MM (default: 02:00)
#   BACKUP_CONFIG_RUN_ON_START  — run immediately on service start (default: true)
#   BACKUP_CONFIG_KEEP          — number of backups to retain (default: 10)
#   BACKEND_URL                 — base URL of the backend service (default: http://backend:4000)

class BackupConfigJob < BaseJob
  BACKEND_URL  = ENV.fetch('BACKEND_URL', 'http://backend:4000')
  BACKUP_DIR   = ENV.fetch('BACKUP_CONFIG_DIR', '/app/backups')
  BACKUP_TIME  = ENV.fetch('BACKUP_CONFIG_TIME', '02:00')
  RUN_ON_START = ENV.fetch('BACKUP_CONFIG_RUN_ON_START', 'true') == 'true'
  KEEP         = ENV.fetch('BACKUP_CONFIG_KEEP', '10').to_i

  def self.schedule(scheduler)
    validate_config!

    if RUN_ON_START
      log.info('Running initial backup on start')
      new.run
    end

    scheduler.every('1d', first_at: next_occurrence(BACKUP_TIME)) { new.run }
    log.info("Scheduled daily at #{BACKUP_TIME}")
  end

  def run
    log.info('Starting backup')
    content = download_config
    path = save(content)
    rotate
    log.info("Backup saved: #{path}")
  rescue => e
    log.error("Backup failed: #{e.class}: #{e.message}")
  end

  private

  def download_config
    uri = URI("#{BACKEND_URL}/api/system/config")
    log.info("Fetching #{uri}")

    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.open_timeout = 10
      http.read_timeout = 60
      http.get(uri.request_uri)
    end

    raise "Backend returned #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    log.info("Downloaded #{response.body.bytesize} bytes")
    response.body
  end

  def save(content)
    FileUtils.mkdir_p(BACKUP_DIR)
    filename = "keenetic-config-#{Time.now.strftime('%Y%m%d-%H%M%S')}.txt"
    path = File.join(BACKUP_DIR, filename)
    File.write(path, content)
    path
  end

  def rotate
    files = Dir[File.join(BACKUP_DIR, 'keenetic-config-*.txt')].sort
    return unless files.size > KEEP

    files.first(files.size - KEEP).each do |old|
      File.delete(old)
      log.info("Removed old backup: #{File.basename(old)}")
    end
  end

  def self.validate_config!
    errors = []
    errors << "BACKUP_CONFIG_TIME \"#{BACKUP_TIME}\" must be HH:MM" unless BACKUP_TIME.match?(/\A([01]\d|2[0-3]):[0-5]\d\z/)
    errors << "BACKUP_CONFIG_KEEP must be a positive integer" unless KEEP > 0

    return if errors.empty?

    errors.each { |e| log.error("Config error: #{e}") }
    raise "#{name} misconfigured, job will not be scheduled"
  end

  def self.next_occurrence(time_str)
    hour, min = time_str.split(':').map(&:to_i)
    now = Time.now
    candidate = Time.new(now.year, now.month, now.day, hour, min, 0)
    candidate <= now ? candidate + 86_400 : candidate
  end
end
