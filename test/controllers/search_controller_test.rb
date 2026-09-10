require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "displays the requested region" do
    get root_url, params: { region: "Europe" }

    assert_response :success
    assert_select "h1 .region", text: "Europe"
  end

  test "renders the summary keys context lines and snapshot freshness" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_response :success
    assert_select "table.keys tbody tr", count: 2
    assert_select "table.lines tbody tr", count: 4
    assert_select "table.keys td.multi", text: /FCS-CPN-100.*FCS-MPN-A/m
    assert_select ".freshness", text: /Sep 07, 15:38.*CSR_OSOR_AMERICAS.*##{csr_snapshots(:current).id}/m
    assert_select ".cards .card:nth-child(2) .value", text: "2"
  end

  test "marks every source without an active snapshot as not loaded" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".sources .source.live", count: 1
    assert_select ".sources .source.not-loaded", count: 4
  end

  test "summarizes the search and offers it as an email draft" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".narrative li", minimum: 1
    assert_select ".narrative a[href^='mailto:?'][href*='subject=CSR'][href*='body=CPN']"
  end

  test "exports every open line of the search as CSV" do
    get search_url(format: :csv), params: { search_type: "cpn", value: "CPN-100" }

    assert_response :success
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal SearchController::CSV_COLUMNS.map(&:to_s), rows.first
    assert_equal 4, rows.size - 1
  end
end
