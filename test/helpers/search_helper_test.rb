require "test_helper"

class SearchHelperTest < ActionView::TestCase
  test "short_date shows the year only outside the current year" do
    this_year = Date.current.change(month: 3, day: 7)

    assert_equal "Mar 07", short_date(this_year)
    assert_equal "Mar 07, #{this_year.year - 1}", short_date(this_year.prev_year)
    assert_equal "—", short_date(nil)
  end
end
