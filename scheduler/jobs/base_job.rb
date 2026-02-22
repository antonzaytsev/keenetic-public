# frozen_string_literal: true

class BaseJob
  def self.log
    @log ||= Logger.new($stdout).tap do |l|
      l.formatter = proc { |sev, time, _, msg|
        "#{time.strftime('%Y-%m-%d %H:%M:%S')} [#{sev}] [#{name}] #{msg}\n"
      }
    end
  end

  def log
    self.class.log
  end

  # Each subclass must implement:
  #   self.schedule(scheduler) — register itself with the Rufus scheduler
  #   run                      — perform the actual work
  def self.schedule(_scheduler)
    raise NotImplementedError, "#{name} must implement .schedule"
  end

  def run
    raise NotImplementedError, "#{self.class.name} must implement #run"
  end
end
