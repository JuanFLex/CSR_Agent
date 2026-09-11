require "test_helper"

class Usage::ReportTest < ActiveSupport::TestCase
  test "summary counts registered users, who searched, searches and exports since the cutoff" do
    summary = Usage::Report.new(since: "2026-09-11").summary

    assert_equal User.count, summary["registered"]
    assert_equal 2, summary["searched"]     # regular + admin, each searched on/after the cutoff
    assert_equal 2, summary["searches"]     # search_in_period + no_results_search
    assert_equal 1, summary["exports"]      # export_in_period
  end

  test "no_results_rate is the share of searches that found zero part keys" do
    rate = Usage::Report.new(since: "2026-09-11").no_results_rate

    assert_equal 50.0, rate # 1 of the 2 searches since the cutoff found nothing
  end
end
