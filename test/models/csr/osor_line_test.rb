require "test_helper"

module Csr
  class OsorLineTest < ActiveSupport::TestCase
    test "the two amount columns are computed, never stored" do
      line = OsorLine.new(baan_ordered: 3, price: 2.5, amount: 8)

      assert_equal 7.5, line.amount_qty_price
      assert_equal 0.5, line.amount_discrepancy
      assert_nil OsorLine.new(price: 2).amount_qty_price, "no quantity, no product"
      assert_not_includes OsorLine.column_names, "amount_qty_price"
    end

    test "a sub-unit price survives the trip to the screen" do
      line = OsorLine.new(baan_ordered: 399_000, price: 0.44)

      assert_equal 175_560, line.amount_qty_price
    end

    test "cpo and so read as one reference, with or without a position" do
      assert_equal "4502398-10", OsorLine.new(cpo: "4502398", cpo_pos: "10").cpo_ref
      assert_equal "4502398", OsorLine.new(cpo: "4502398").cpo_ref
    end
  end
end
