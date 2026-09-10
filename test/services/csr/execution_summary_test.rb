require "test_helper"

module Csr
  class ExecutionSummaryTest < ActiveSupport::TestCase
    setup do
      @snapshot = csr_snapshots(:current)
      @keys = PartKey.where(id: %i[primary alternate without_lines].map { |key| csr_part_keys(key).id })
                     .order(:key_value)
    end

    test "counts matched keys and aggregates only their lines in the supplied snapshot" do
      assert_equal(
        {
          combos_found: 3,
          open_lines: 4,
          misses: 2,
          etd_min: Time.utc(2026, 9, 9, 8),
          etd_max: Time.utc(2026, 9, 12, 8),
          open_qty: BigDecimal("19.5"),
          unconfirmed: 1
        },
        numbers
      )
    end

    test "can summarize a superseded snapshot without reading the current one" do
      assert_equal(
        {
          combos_found: 3,
          open_lines: 1,
          misses: 0,
          etd_min: Time.utc(2026, 1, 1, 8),
          etd_max: Time.utc(2026, 1, 1, 8),
          open_qty: BigDecimal("9999"),
          unconfirmed: 0
        },
        numbers(snapshot: csr_snapshots(:previous))
      )
    end

    test "returns empty numbers while preserving the count of keys without lines" do
      empty = { combos_found: 0, open_lines: 0, misses: 0, etd_min: nil, etd_max: nil, open_qty: 0, unconfirmed: 0 }

      assert_equal empty, numbers(PartKey.none)
      assert_equal empty.merge(combos_found: 1), numbers(PartKey.where(id: csr_part_keys(:without_lines).id))

      Snapshot.active.update_all(status: :superseded)
      assert_equal empty, numbers(snapshot: nil)
    end

    test "ignores null quantities and dates without changing line or miss counts" do
      OsorLine.in_snapshot(@snapshot).where(part_key_id: @keys.select(:id))
              .update_all(baan_ordered: nil, cdd: nil)

      assert_equal(
        { combos_found: 3, open_lines: 4, misses: 2, etd_min: nil, etd_max: nil, open_qty: 0, unconfirmed: 4 },
        numbers
      )
    end

    test "aggregates all numbers in one query" do
      assert_queries_count(1) { numbers }
    end

    test "requires an explicit snapshot and never selects a fallback" do
      assert_raises(ArgumentError) { ExecutionSummary.new(@keys) }

      Snapshot.stub(:current, ->(*) { flunk "The caller must select the snapshot" }) do
        assert_equal(
          { combos_found: 0, open_lines: 0, misses: 0, etd_min: nil, etd_max: nil, open_qty: 0, unconfirmed: 0 },
          numbers(snapshot: nil)
        )
      end
    end

    private

    def numbers(part_keys = @keys, snapshot: @snapshot)
      ExecutionSummary.new(part_keys, snapshot: snapshot).call
    end
  end
end
