require "test_helper"

module Csr
  class BufferSummaryTest < ActiveSupport::TestCase
    setup do
      @snapshot = Snapshot.create!(region: "Americas", source_type: "buffer", status: :active, activated_at: Time.current)
      @key = csr_part_keys(:primary)
    end

    test "reports the lowest week against safety stock and the first week at target" do
      weeks(0.5, -1, 1, 3)

      assert_equal(-1, position.min_vs_ss)
      assert_equal Date.new(2026, 10, 10), position.at_target_from
      assert_predicate position, :below_target?
    end

    test "a key that never drops below its safety stock is not below target" do
      weeks(1, 2.5)

      assert_not_predicate position, :below_target?
      assert_not_predicate position, :no_target?
    end

    test "a key with no safety stock has no target rather than a zero" do
      weeks(0, 0, safety_stock: 0)

      assert_predicate position, :no_target?
      assert_not_predicate position, :below_target?
      assert_nil position.at_target_from
    end

    test "a key whose balance touches zero keeps its date" do
      weeks(0, 2)

      assert_predicate position, :below_target?
      assert_equal Date.new(2026, 10, 3), position.at_target_from
    end

    test "takes the extremes across every row of the key and ignores the rows with no target" do
      weeks(2, 1.5, fpn: "FCS-MPN-A")
      weeks(0, 0, fpn: "FCS1-MPN-A", safety_stock: 0)

      assert_equal 1.5, position.min_vs_ss
      assert_not_predicate position, :below_target?
    end

    test "leaves out the keys the buffer report does not carry" do
      weeks(1)

      assert_equal [ @key.id ], summary(PartKey.where(cpn: "CPN-100")).keys
    end

    test "is empty until a buffer snapshot exists" do
      assert_empty BufferSummary.new(PartKey.all, snapshot: nil).call
    end

    private

    def weeks(*ratios, safety_stock: 8000, fpn: "FCS-MPN-A")
      ratios.each_with_index do |ratio, index|
        BufferLine.create!(snapshot: @snapshot, part_key: @key, cpn: @key.cpn, mpn: @key.mpn, fpn: fpn,
                           safety_stock: safety_stock, bucket_date: Date.new(2026, 9, 26) + index.weeks, vs_ss: ratio)
      end
    end

    def summary(keys = PartKey.all) = BufferSummary.new(keys, snapshot: @snapshot).call
    def position = summary[@key.id]
  end
end
