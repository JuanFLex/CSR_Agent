require "test_helper"
require "fugit"

module Csr
  # config/recurring.yml is plain YAML that nothing else validates: a typo in
  # the class name or in the schedule is accepted at write time and then simply
  # never runs, which from the outside looks exactly like data that went stale
  # on its own. These assertions turn that silence into a failing test.
  #
  # Solid Queue's own RecurringTask is an Active Record model and the test
  # database carries no solid_queue tables, so this checks the same two things
  # its validations do — Fugit parses the schedule, and the class resolves —
  # without needing that connection.
  class OsorIngestScheduleTest < ActiveSupport::TestCase
    setup do
      @config = Rails.application.config_for(:recurring, env: "production").fetch(:osor_ingest)
    end

    test "names a job class that exists and is actually a job" do
      job_class = @config[:class].safe_constantize

      assert_equal OsorIngestJob, job_class
      assert_operator job_class, :<, ActiveJob::Base
    end

    test "polls every 15 minutes" do
      cron = ::Fugit.parse(@config[:schedule])

      assert_instance_of ::Fugit::Cron, cron, "Solid Queue only accepts schedules Fugit reads as a cron"

      first = cron.next_time(Time.utc(2026, 9, 9, 12)).to_utc_time
      second = cron.next_time(first).to_utc_time

      assert_equal 15.minutes, second - first
    end

    test "passes no arguments so the region is named in one place only" do
      assert_nil @config[:args], "the region comes from Csr::DEFAULT_REGION via the job's own default"
    end
  end
end
