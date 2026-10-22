require "test_helper"

module Reporting
  # The read side of the Demand report, against the stand-in reporting
  # database: the query the ingest test fakes. The table is built the way the
  # SSIS package creates it, not from the map, so a column the map misnames
  # fails here.
  class DemandStagingTest < ActiveSupport::TestCase
    TEXT_COLUMNS = %w[DELIVERY_ADDRESS CUSTOMER_NAME CPN COMPANY FCP_PART MANUFACTURER_PART SNAPSHOT_DATE STATUS].freeze
    NUMBER_COLUMNS = (%w[EFF_LEAD_TIME] + (9..60).map { |week| "F#{week}" } +
                      %w[TOTALS VARIATION_INSIDE_LT VARIATION_INSIDE_LT_PCT TOTAL_VARIATION TOTAL_VARIATION_PCT
                         VARIATION_INSIDE_LT_USD TOTAL_VARIATION_USD]).freeze

    setup do
      Base.connection.create_table(DemandStaging.table_name, id: false, force: true) do |t|
        TEXT_COLUMNS.each { |column| t.string(column) }
        NUMBER_COLUMNS.each { |column| t.float(column) }
        t.datetime :loaded_at
      end
      demand_row("SNAPSHOT_DATE" => "10/10/2026", "F9" => 0, "F10" => 900, "VARIATION_INSIDE_LT_PCT" => 0.3)
      demand_row("SNAPSHOT_DATE" => "10/3/2026", "F9" => 500, "F10" => 700, "VARIATION_INSIDE_LT_PCT" => 0.3)
      demand_row("SNAPSHOT_DATE" => "Delta in bucket", "F9" => -500, "F10" => 200, "VARIATION_INSIDE_LT_PCT" => 9.0)
      demand_row("SNAPSHOT_DATE" => "Sales", "VARIATION_INSIDE_LT_PCT" => 0.3)
    end

    teardown do
      Base.connection.drop_table(DemandStaging.table_name, if_exists: true)
    end

    test "reads one row per part: the Sales row's mapped columns and its two snapshots, oldest first" do
      rows = DemandStaging.rows

      assert_equal 1, rows.size
      row = rows.first
      assert_equal Csr::Demand::ColumnMap::COLUMNS.keys.sort, (row.keys - %w[OLD_SNAPSHOT_ON NEW_SNAPSHOT_ON OLD_WEEKS NEW_WEEKS]).sort
      assert_equal [ "CPN-900", "MPN-Z", 0.3 ], row.values_at("CPN", "MANUFACTURER_PART", "VARIATION_INSIDE_LT_PCT")
      assert_equal [ Date.new(2026, 10, 3), Date.new(2026, 10, 10) ], row.values_at("OLD_SNAPSHOT_ON", "NEW_SNAPSHOT_ON"), "dates are American: 10/3 is October 3"
      assert_equal 52, row["OLD_WEEKS"].size
      assert_equal [ [ 500, 700 ], [ 0, 900 ] ], [ row["OLD_WEEKS"].first(2), row["NEW_WEEKS"].first(2) ]
      assert_equal 4, DemandStaging.count
    end

    test "a table whose week columns are named some other way gives no weeks rather than zeros" do
      DemandStaging.stub(:week_columns, []) do
        assert_equal [ nil, nil ], DemandStaging.rows.first.values_at("NEW_SNAPSHOT_ON", "NEW_WEEKS")
      end
    end

    test "tells a load's time and its age" do
      assert_equal Time.zone.local(2026, 10, 19, 13, 27, 36), DemandStaging.watermark
      assert_operator DemandStaging.age, :>, 0
    end

    private

    def demand_row(values)
      Base.connection.insert_fixture(
        { "CPN" => "CPN-900", "MANUFACTURER_PART" => "MPN-Z", "STATUS" => "Strong variation - Need confirmation",
          "loaded_at" => "2026-10-19 13:27:36" }.merge(values),
        DemandStaging.table_name
      )
    end
  end
end
