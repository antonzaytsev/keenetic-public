#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require 'rufus-scheduler'

# Load base first, then all job files
require_relative 'jobs/base_job'
Dir[File.join(__dir__, 'jobs', '*.rb')].each { |f| require f }

log = Logger.new($stdout)
log.formatter = proc { |sev, time, _, msg|
  "#{time.strftime('%Y-%m-%d %H:%M:%S')} [#{sev}] [Scheduler] #{msg}\n"
}

job_classes = BaseJob.subclasses
log.info("Starting scheduler — #{job_classes.size} job(s) found: #{job_classes.map(&:name).join(', ')}")

scheduler = Rufus::Scheduler.new

job_classes.each do |job_class|
  begin
    job_class.schedule(scheduler)
  rescue => e
    log.error("Failed to schedule #{job_class.name}: #{e.message}")
  end
end

log.info('All jobs registered, running...')
scheduler.join
