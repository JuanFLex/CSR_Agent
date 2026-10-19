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
      demand_row("SNAPSHOT_DATE" => "10/3/2026", "VARIATION_INSIDE_LT_PCT" => 9.0)
      demand_row("SNAPSHOT_DATE" => "Sales", "VARIATION_INSIDE_LT_PCT" => 0.3)
    end

    teardown do
      Base.connection.drop_table(DemandStaging.table_name, if_exists: true)
    end

    test "reads only the Sales row of each part, with every mapped column" do
      rows = DemandStaging.rows

      assert_equal 1, rows.size
      assert_equal Csr::Demand::ColumnMap::COLUMNS.keys.sort, rows.first.keys.sort
      assert_equal [ "CPN-900", "MPN-Z", 0.3 ], rows.first.values_at("CPN", "MANUFACTURER_PART", "VARIATION_INSIDE_LT_PCT")
      assert_equal 2, DemandStaging.count
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
