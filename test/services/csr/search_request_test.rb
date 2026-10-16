require "test_helper"

module Csr
  class SearchRequestTest < ActiveSupport::TestCase
    test "exposes form options and shared defaults" do
      assert_equal(
        [ [ "CPN", "cpn" ], [ "MPN", "mpn" ], [ "CPO+Line", "cpo_line" ], [ "SO", "so" ], [ "FPN", "fpn" ] ],
        SearchRequest.options_for_select
      )

      search = SearchRequest.new(search_type: "invalid", value: " CPN-100 ", region: " ")

      assert_equal SearchRequest::DEFAULT_TYPE, search.search_type
      assert_equal DEFAULT_REGION, search.region
      assert_equal "CPN-100", search.value
      assert_equal SearchRequest::LINES_PER_PAGE, search.lines.limit_value
      assert_equal 2, search.lines(limit: 2).limit_value
      assert_equal 4, search.lines(limit: 2, page: 3).offset_value
    end

    test "keeps the same snapshot across resolution summary context and lines" do
      search = SearchRequest.new(search_type: "cpn", value: "CPN-100")
      snapshot = search.snapshot

      csr_snapshots(:previous).activate!

      assert_same snapshot, search.snapshot
      assert_equal 2, search.part_keys.count
      assert_equal 4, search.summary.fetch(:open_lines)
      assert_equal 2, search.summary.fetch(:misses)
      assert_equal [ snapshot.id ], search.lines.pluck(:snapshot_id).uniq
      assert_equal %w[FCS-CPN-100 FCS-MPN-A], search.context.fetch(csr_part_keys(:primary).id).fetch(:fpn)
    end

    test "keeps an absent snapshot for the entire request" do
      Snapshot.active.update_all(status: :superseded)
      search = SearchRequest.new(search_type: "cpn", value: "CPN-100")

      assert_queries_count(1) do
        assert_nil search.snapshot
        assert_nil search.snapshot
      end

      csr_snapshots(:previous).activate!

      assert_nil search.snapshot
      assert_empty search.part_keys
      assert_equal 0, search.summary.fetch(:combos_found)
      assert_equal 0, search.summary.fetch(:open_lines)
      assert_empty search.lines
      assert_empty search.context
    end

    test "need dates keep only the PDDs still ahead, per escalation FPN" do
      search = SearchRequest.new(search_type: "cpn", value: "CPN-100")

      assert_equal({ "FCS-CPN-100" => nil }, search.need_dates, "every fixture PDD is past due")

      travel_to Date.new(2026, 9, 1) do
        assert_equal Date.new(2026, 9, 10), SearchRequest.new(search_type: "cpn", value: "CPN-100").need_dates["FCS-CPN-100"].to_date
      end
    end

    test "escalations match the FPNs on the orders, except on an MPN search" do
      by_cpn = SearchRequest.new(search_type: "cpn", value: "CPN-100").escalations
      by_mpn = SearchRequest.new(search_type: "mpn", value: "MPN-A").escalations

      assert_not_includes by_cpn, csr_escalations(:other_fpn), "same MPN, another FPN"
      assert_includes by_cpn, csr_escalations(:shortage)
      assert_includes by_mpn, csr_escalations(:other_fpn)
    end
  end
end
