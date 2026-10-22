require "test_helper"

class ChartHelperTest < ActionView::TestCase
  WEEKS = Array.new(4) { |i| Date.new(2026, 10, 3) + 7 * i }

  test "the axis steps are clean numbers that cover the values and zero" do
    assert_equal [ -60_000, -40_000, -20_000, 0 ], send(:chart_ticks, -43_645, 0)
    assert_equal [ 0, 1 ], send(:chart_ticks, 0, 0)
  end

  test "a week the report lacks breaks the line instead of bridging it" do
    html = week_chart(WEEKS, [ { name: "Balance", values: [ 1, nil, 2, 3 ], kind: :line, tone: "primary" } ], label: "x")

    assert_equal 1, html.scan("<polyline").size
    assert_equal 2, html.scan("<circle").size, "the lone first week as a dot, and the end dot"
    assert_includes html, "Oct 24, 2026\nBalance: 3"
  end

  test "bars grow from zero and a zero week draws none" do
    html = week_chart(WEEKS, [ { name: "Balance", values: [ 0, -5, 0, -10 ], kind: :bars, tone: "short" } ], label: "x")

    assert_equal 2, html.scan("<path").size
  end

  test "nothing to draw says so" do
    assert_includes week_chart([], [ { name: "Balance", values: [], kind: :line } ], label: "x"), "No weeks to draw"
  end

  test "a young history says when it starts" do
    assert_match(/History starts Oct 3, 2026/, history_note(WEEKS.first(1)))
    assert_match(/since Oct 3, 2026/, history_note(WEEKS))
  end
end
