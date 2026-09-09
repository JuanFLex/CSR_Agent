require "test_helper"

module Csr
  module Osor
    class IngestTest < ActiveSupport::TestCase
      setup do
        @snapshot = csr_snapshots(:current)
      end

      test "zero rows fail the new snapshot and keep the previous one active" do
        result = ingest(rows: [])

        assert_predicate result, :failed?
        assert_predicate result.snapshot, :failed?
        assert_equal 0, result.snapshot.row_count
        assert_match(/0 rows/, result.snapshot.notes)
        assert_equal @snapshot, Snapshot.current("osor")
        assert_predicate @snapshot.reload, :active?
      end

      test "a shrunken load keeps the previous snapshot active" do
        result = ingest(rows: [ row ])

        assert_predicate result, :failed?
        assert_predicate result.snapshot, :failed?
        assert_equal 1, result.snapshot.row_count
        assert_match(/beyond the 30% tolerance/, result.snapshot.notes)
        assert_equal @snapshot, Snapshot.current("osor")
        assert_predicate @snapshot.reload, :active?
      end

      test "unchanged or older watermarks skip without reading rows or writing records" do
        [ @snapshot.source_modified_at, @snapshot.source_modified_at - 1.hour ].each do |watermark|
          result = nil

          assert_no_difference [ "Csr::Snapshot.count", "Csr::OsorLine.count", "Csr::PartKey.count" ] do
            result = ingest(rows: nil, watermark: watermark)
          end

          assert_predicate result, :skipped?
          assert_equal @snapshot, result.snapshot
          assert_predicate @snapshot.reload, :active?
        end
      end

      test "forcing a load bypasses the watermark skip but not the zero row guard" do
        result = ingest(rows: [], watermark: @snapshot.source_modified_at, force: true)

        assert_predicate result, :failed?
        assert_equal @snapshot, Snapshot.current("osor")
        assert_predicate @snapshot.reload, :active?
      end

      test "activates a complete load reusing keys and retaining rejected lines" do
        rows = [
          row("ITEM" => "FCS-EXISTING", "baan_ordered" => "1,234.50"),
          row("CPN_EDI" => " CPN-100 ", "MPN" => " MPN-A ", "ITEM" => "FCS-ALTERNATE"),
          row("CPN_EDI" => " NEW-CPN ", "MPN" => "NEW-MPN", "COMMDELDATE" => Time.utc(2026, 9, 12)),
          row("CPN_EDI" => "NEW-CPN", "MPN" => "NEW-MPN", "COMMDELDATE" => Time.utc(2026, 9, 12)),
          row("MPN" => nil)
        ]
        result = nil
        key_builder = PartKey.method(:build_key)
        key_builds = 0
        count_key_builds = ->(cpn, mpn) {
          key_builds += 1
          key_builder.call(cpn, mpn)
        }

        PartKey.stub(:build_key, count_key_builds) do
          assert_difference "Csr::PartKey.count", 1 do
            result = ingest(rows: rows)
          end
        end

        assert_equal rows.size, key_builds
        assert_predicate result, :activated?
        assert_equal result.snapshot, Snapshot.current("osor")
        assert_predicate @snapshot.reload, :superseded?
        assert_equal 5, result.snapshot.row_count
        assert_equal 1, result.snapshot.rejected_count

        lines = result.snapshot.osor_lines
        new_key = PartKey.find_by!(key_value: "NEW-CPN|NEW-MPN")
        assert_equal({ csr_part_keys(:primary).id => 2, new_key.id => 2, nil => 1 }, lines.group(:part_key_id).count)
        assert_equal 2, lines.missed.count
        assert_equal BigDecimal("1234.50"), lines.find_by!(fpn: "FCS-EXISTING").baan_ordered
      end

      test "retains a batch with no usable keys and counts every rejected line" do
        result = nil

        assert_no_difference "Csr::PartKey.count" do
          result = ingest(rows: Array.new(5) { row("MPN" => nil) })
        end

        assert_predicate result, :activated?
        assert_equal 5, result.snapshot.row_count
        assert_equal 5, result.snapshot.rejected_count
        assert_equal 5, result.snapshot.osor_lines.where(part_key_id: nil).count
      end

      private

      def row(attributes = {})
        {
          "CPN_EDI" => "CPN-100", "MPN" => "MPN-A", "ITEM" => "FCS-CPN-100",
          "baan_ordered" => "1.25", "PLANDELDATE" => Time.utc(2026, 9, 10),
          "COMMDELDATE" => Time.utc(2026, 9, 9)
        }.merge(attributes)
      end

      def ingest(rows:, watermark: @snapshot.source_modified_at + 1.hour, **options)
        staging = Minitest::Mock.new
        staging.expect(:watermark, watermark)
        staging.expect(:table_name, "CSR_OSOR_AMERICAS")

        # Only the read interface is faked; snapshots, keys and lines use Postgres.
        if rows
          sql = "SELECT * FROM CSR_OSOR_AMERICAS"
          relation = Minitest::Mock.new
          relation.expect(:to_sql, sql)
          connection = Minitest::Mock.new
          connection.expect(:select_all, rows, [ sql ])
          staging.expect(:all, relation)
          staging.expect(:connection, connection)
        end

        result = Reporting::OsorStaging.stub(:for_region, staging) { Ingest.new(**options).call }

        staging.verify
        relation&.verify
        connection&.verify
        result
      end
    end
  end
end
