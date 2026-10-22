require "test_helper"

class SearchLoggingTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:regular) }

  test "a search writes exactly one search log" do
    assert_difference -> { Csr::SearchLog.where(kind: "search").count }, 1 do
      get root_url, params: { search_type: "cpn", value: "CPN-100" }
    end
  end

  test "following the pager forward and back does not log more searches" do
    template = csr_osor_lines(:on_time).attributes.slice(*Csr::OsorLine.column_names).except("id")
    Csr::OsorLine.insert_all!(Array.new(Csr::SearchRequest::LINES_PER_PAGE) { template.dup })

    assert_difference -> { Csr::SearchLog.where(kind: "search").count }, 1 do
      get root_url, params: { search_type: "mpn", value: "MPN-A" }
      assert_response :success
      next_page = css_select(".pager a[aria-label='Next page']").sole["href"]
      get next_page
      assert_response :success
      previous_page = css_select(".pager a[aria-label='Previous page']").sole["href"]
      get previous_page
      assert_response :success
    end
  end

  test "moving between the menu's pages does not log more searches" do
    assert_difference -> { Csr::SearchLog.where(kind: "search").count }, 1 do
      get root_url, params: { search_type: "cpn", value: "CPN-100" }
      get css_select(".sidenav a").find { |a| a.text.include?("Buffer Readiness") }["href"]
      assert_response :success
      get css_select(".sidenav a").find { |a| a.text.include?("Dashboard") }["href"]
      assert_response :success
    end
  end

  test "an export writes exactly one export log" do
    assert_difference -> { Csr::SearchLog.where(kind: "export").count }, 1 do
      get search_url(format: :csv), params: { search_type: "cpn", value: "CPN-100" }
    end
  end

  test "a blank search writes no log" do
    assert_no_difference -> { Csr::SearchLog.count } do
      get root_url
    end
  end
end
