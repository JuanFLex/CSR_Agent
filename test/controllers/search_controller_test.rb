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
    assert_select ".freshness", text: /CSR_OSOR_AMERICAS.*2026-09-07 15:38.*#{csr_snapshots(:current).id}/m
    assert_select ".cards .card:nth-child(2) .value", text: "2"
  end
end
