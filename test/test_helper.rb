ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "active_record/testing/query_assertions"

module ActiveSupport
  class TestCase
    include ActiveRecord::Assertions::QueryAssertions

    # The reporting stand-in is a single SQLite file, and parallel workers lock
    # each other out of it. The whole suite runs in a couple of seconds, so one
    # process is faster than paying for that contention.
    # ponytail: serial tests; give each worker its own staging file the day the
    # suite is slow enough to need parallelism.
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
