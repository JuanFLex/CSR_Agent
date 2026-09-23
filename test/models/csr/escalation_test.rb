require "test_helper"

module Csr
  class EscalationTest < ActiveSupport::TestCase
    test "tiers by weeks to the earliest need date still ahead" do
      today = Date.new(2026, 9, 23)
      tier = ->(days) { Escalation.tier(today + days, today: today) }

      assert_equal %w[T0 T1 T1 T2 T2 T3 T3 T4], [ 27, 28, 55, 56, 83, 84, 139, 140 ].map(&tier)
      assert_equal "T0", Escalation.tier(nil, today: today), "no need date ahead is the most urgent"
    end

    test "shows the shortage as a positive quantity" do
      assert_equal 1500, Escalation.new(shortage_qty: -1500).shortage_qty
    end
  end
end
