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

    assert_select ".sources .source.live", count: 2
    assert_select ".sources .source.not-loaded", count: 3
  end

  test "summarizes the search and offers it as an email draft" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".narrative li", minimum: 1
    assert_select ".narrative a[href^='mailto:?'][href*='subject=CSR'][href*='body=CPN']"
  end

  test "lists the open escalations raised against the searched MPNs" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.escalations tbody tr", count: 2
    assert_select "table.escalations tbody tr.miss td", text: /20250716610058.2/
    assert_select ".narrative li", text: /2 open escalations on these MPNs, 1 with the line down/
  end

  test "shows the default escalation columns and swaps them for the chosen ones" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.escalations thead th", text: "FET #"
    assert_select "table.escalations thead th", text: "Customer", count: 0

    get root_url, params: { search_type: "cpn", value: "CPN-100", escalation_columns: %w[mpn customer nonsense] }

    assert_select "table.escalations thead th", text: "Customer"
    assert_select "table.escalations thead th", text: "FET #", count: 0
    assert_equal "mpn,customer", cookies[:escalation_columns], "the choice is remembered per browser"
  end

  test "shows the default order columns and swaps them for the chosen ones" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.lines thead th", text: "Need (PDD)"
    assert_select "table.lines thead th", text: "Project", count: 0

    get root_url, params: { search_type: "cpn", value: "CPN-100",
                            line_columns: %w[cpo_ref project amount_qty_price] }

    assert_select "table.lines thead th", text: "Project"
    assert_select "table.lines thead th", text: "Amount = Qty x Price"
    assert_select "table.lines thead th", text: "Need (PDD)", count: 0
  end

  test "falls back to the default columns when the request names none that exist" do
    get root_url, params: { search_type: "cpn", value: "CPN-100", escalation_columns: %w[drop_table] }

    assert_select "table.escalations thead th", text: "FET #"
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
