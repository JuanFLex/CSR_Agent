# Usage metrics for the admin dashboard: who searches, how much, and what
# for. Adapted from snow_agents' Usage module — same Config/report(since:)
# shape — but the source table here is csr_search_logs, one row per search
# or export, not a chat log.
module Usage
  Config = Struct.new(:since, keyword_init: true)

  # UAT started here; anything before this date is noise from earlier testing.
  DEFAULT_SINCE = "2026-09-11".freeze

  def self.config
    @config ||= Config.new(
      # .presence and not fetch: a var declared but empty in the env file
      # would otherwise leave the cutoff blank instead of falling back.
      since: ENV["USAGE_SINCE"].presence || DEFAULT_SINCE
    )
  end

  def self.report(since: nil)
    Report.new(since: since.presence || config.since)
  end

  # For tests that need a different cutoff.
  def self.reset!
    @config = nil
  end
end
