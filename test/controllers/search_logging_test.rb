require "test_helper"

class SearchLoggingTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:regular) }

  test "a search writes exactly one search log" do
    assert_difference -> { Csr::SearchLog.where(kind: "search").count }, 1 do
      get root_url, params: { search_type: "cpn", value: "CPN-100" }
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
