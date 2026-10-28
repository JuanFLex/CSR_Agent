require "test_helper"

module Reporting
  # The read side of the weekly sheets, against the stand-in reporting
  # database: the queries the ingest tests fake.
  class TrendStagingTest < ActiveSupport::TestCase
    setup do
      connection = Base.connection

      connection.create_table(CommitStaging.table_name, id: false, force: true) do |t|
        Csr::Commit::ColumnMap::COLUMNS.each_key { |column| t.string(column) }
        Csr::Commit::ColumnMap::WEEK_COLUMNS.each { |column| t.float(column) }
        t.string :F16
        t.datetime :loaded_at
      end
      commit_row("F3" => "Customer", "F4" => "Delivery Address", "F5" => "CPN",
                 "F6" => "Part", "F7" => "MPN", "F16" => "")
      commit_row("F5" => "CPN-900", "F7" => "MPN-Z", "F16" => "Forecast", "F18" => 4000.0)
      commit_row("F5" => "CPN-900", "F7" => "MPN-Z", "F16" => "Balance", "F18" => -4000.0)

      connection.create_table(VerticalCommitStaging.table_name, id: false, force: true) do |t|
        t.string :DATE
        t.string :CPN
        t.string :END_CUSTOMER
      end
      %w[Date Past 1/2/2027 10/3/2026 10/3/2026 Future].each do |date|
        connection.insert_fixture({ "DATE" => date }, VerticalCommitStaging.table_name)
      end
      { " CPN-900 " => "PHILO", "CPN-901" => "Unknown", "CPN-902" => " ", "CPN-903" => "XYLEM" }.each do |cpn, name|
        connection.insert_fixture({ "DATE" => "10/3/2026", "CPN" => cpn, "END_CUSTOMER" => name }, VerticalCommitStaging.table_name)
      end
    end

    teardown do
      [ CommitStaging, VerticalCommitStaging ].each { |staging| Base.connection.drop_table(staging.table_name, if_exists: true) }
    end

    test "reads only the rows of its own type, with the mapped columns" do
      rows = CommitStaging.rows

      assert_equal 1, rows.size
      assert_equal [ "CPN-900", "MPN-Z", -4000.0 ], rows.first.values_at("F5", "F7", "F18")
      assert_equal 3, CommitStaging.count
    end

    test "tells a load's time and its age" do
      assert_equal Time.zone.local(2026, 10, 12, 10, 41), CommitStaging.watermark
      assert_operator CommitStaging.age, :>, 0
    end

    test "the header row has to name the columns the way the map reads them" do
      assert_predicate CommitStaging, :layout_ok?

      # A column added before CPN: every label sits one column to the right.
      CommitStaging.connection.execute(%(UPDATE "CSR_CustomerCommitment" SET "F6" = 'CPN', "F5" = 'New column' WHERE "F3" = 'Customer'))

      assert_not_predicate CommitStaging, :layout_ok?
    end

    test "the first week is the earliest date, read the American way" do
      assert_equal Date.new(2026, 10, 3), VerticalCommitStaging.first_week
      assert_equal Date.new(2027, 1, 2), VerticalCommitStaging.parse("1/2/2027"), "January 2, not February 1"
      assert_nil VerticalCommitStaging.parse("Past")
    end

    test "gives each CPN its end customer, and nothing for the ones the sheet does not know" do
      assert_equal({ "CPN-900" => "PHILO", "CPN-903" => "XYLEM" }, VerticalCommitStaging.end_customers)
    end

    private

    def commit_row(values)
      Base.connection.insert_fixture(values.merge("loaded_at" => "2026-10-12 10:41:00"), CommitStaging.table_name)
    end
  end
end
