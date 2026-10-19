require "test_helper"

module Csr
  class DemandSummaryTest < ActiveSupport::TestCase
    setup do
      @snapshot = Snapshot.create!(region: "Americas", source_type: "demand", status: :active, activated_at: Time.current)
      @key = csr_part_keys(:primary)
    end

    test "reads the status without its instruction and flags the movement" do
      moved(0.3)

      assert_equal "Strong variation", position.label
      assert_not_predicate position, :steady?
      assert_equal :red, position.flag
    end

    test "flags exactly 0.25 as red" do
      moved(0.25)

      assert_equal :red, position.flag
    end

    test "flags 0.15 as yellow" do
      moved(0.15)

      assert_equal :yellow, position.flag
    end

    test "a drop is never flagged, however deep" do
      moved(-0.5)

      assert_equal :green, position.flag
    end

    test "a key with two rows shows the one that is not steady" do
      # The steady row moved more, so only the steady rule can pick the other.
      moved(0.4, status: "Steady demand - Ok to process", customer_name: "ZZZFCS003")
      moved(0.2, status: "Strong variation - Need confirmation", customer_name: "ZZZCAR018")

      assert_equal "Strong variation", position.label
    end

    test "a key with two unsteady rows shows the widest movement" do
      moved(0.2, status: "Strong variation - Need confirmation", customer_name: "ZZZFCS003")
      moved(-0.4, status: "Total Drop - Need confirmation", customer_name: "ZZZCAR018")

      assert_equal "Total Drop", position.label
    end

    test "is empty until a demand snapshot exists" do
      assert_empty DemandSummary.new(PartKey.all, snapshot: nil).call
    end

    private

    def moved(pct, status: "Strong variation - Need confirmation", customer_name: "ZZZCAR018")
      DemandLine.create!(snapshot: @snapshot, part_key: @key, cpn: @key.cpn, mpn: @key.mpn, status: status,
                         customer_name: customer_name, lt_variation: pct * 10_000, lt_variation_pct: pct)
    end

    def position = DemandSummary.new(PartKey.all, snapshot: @snapshot).call[@key.id]
  end
end
