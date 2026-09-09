require "test_helper"

module Csr
  class KeyContextTest < ActiveSupport::TestCase
    test "collects each context dimension from only the selected keys and snapshot" do
      keys = PartKey.where(id: %i[primary without_lines].map { |key| csr_part_keys(key).id })
      snapshot = csr_snapshots(:current)
      context = nil

      assert_queries_count(1) do
        context = KeyContext.new(keys, snapshot: snapshot).call
      end

      assert_equal(
        {
          csr_part_keys(:primary).id => {
            fpn: %w[FCS-CPN-100 FCS-MPN-A],
            customer: [ "Customer A", "Customer B" ],
            ship_to: %w[SHIP-A SHIP-B],
            site: %w[GDL MTY]
          }
        },
        context
      )
      assert_equal({}, KeyContext.new(keys, snapshot: nil).call)
    end
  end
end
