# Week-by-week charts as inline SVG, drawn on the server: no charting library,
# the same choice as the usage dashboard's CSS bars. One y axis, a hairline
# grid, 2px lines, and a column per week whose tooltip reads every series.
module ChartHelper
  WIDTH = 560
  HEIGHT = 200
  PAD = { top: 12, right: 14, bottom: 24, left: 50 }.freeze

  # dates: one Date per week. series: hashes of
  #   name:   what the legend and the tooltip call it
  #   values: one number (or nil) per date
  #   kind:   :line, :bars (from zero) or :reference (a dashed target)
  #   tone:   the CSS class that colours it (primary, previous, reference, short)
  def week_chart(dates, series, label:)
    values = series.flat_map { |s| s[:values] }.compact.map(&:to_f)
    return tag.p("No weeks to draw.", class: "hint") if dates.empty? || values.empty?

    ticks = chart_ticks([ values.min, 0 ].min, [ values.max, 0 ].max)
    x = chart_x(dates.size)
    y = ->(value) { chart_y(value, ticks.first, ticks.last) }

    parts = ticks.map do |tick|
      tag.line(x1: PAD[:left], x2: WIDTH - PAD[:right], y1: y.(tick), y2: y.(tick), class: tick.zero? ? "axis" : "grid") +
        tag.text(compact_number(tick), x: PAD[:left] - 6, y: y.(tick) + 4, class: "tick", "text-anchor": "end")
    end
    parts += chart_date_labels(dates, x)
    parts += series.map { |s| chart_series(s, x, y, dates.size) }
    parts += chart_hover_columns(dates, series, x)

    tag.figure(class: "chart") do
      safe_join([
        (chart_legend(series) if series.many?),
        tag.svg(safe_join(parts), viewBox: "0 0 #{WIDTH} #{HEIGHT}", role: "img", "aria-label": label)
      ].compact)
    end
  end

  # What a week-over-week chart covers, so a short history reads as young
  # rather than as flat.
  def history_note(weeks)
    return "History starts with the next weekly report." if weeks.empty?
    return "History starts #{weeks.first.strftime("%b %-d, %Y")}: a point is added with every weekly report." if weeks.one?

    "One point per weekly report, since #{weeks.first.strftime("%b %-d, %Y")}."
  end

  private

  # Clean steps (1, 2 or 5 times a power of ten) that cover min..max.
  def chart_ticks(min, max)
    return [ 0, 1 ] if min == max

    raw = (max - min) / 4.0
    magnitude = 10**Math.log10(raw).floor
    step = [ 1, 2, 5, 10 ].map { |m| m * magnitude }.find { |s| s >= raw }
    ((min / step).floor..(max / step).ceil).map { |i| i * step }
  end

  def chart_x(count)
    span = WIDTH - PAD[:left] - PAD[:right]
    ->(i) { PAD[:left] + (count == 1 ? span / 2.0 : span * i / (count - 1).to_f) }
  end

  def chart_y(value, low, high)
    span = HEIGHT - PAD[:top] - PAD[:bottom]
    (PAD[:top] + span * (high - value.to_f) / (high - low)).round(1)
  end

  # About six dates along the bottom; the year only where it changes.
  def chart_date_labels(dates, x)
    every = [ (dates.size / 6.0).ceil, 1 ].max
    year = nil
    dates.each_with_index.filter_map do |date, i|
      next unless (i % every).zero?

      text = date.strftime("%b %-d")
      text += date.strftime(" ’%y") if year && date.year != year
      year = date.year
      tag.text(text, x: x.(i), y: HEIGHT - 6, class: "tick", "text-anchor": "middle")
    end
  end

  def chart_series(series, x, y, count)
    points = series[:values].each_with_index.filter_map { |value, i| [ x.(i).round(1), y.(value) ] if value }

    case series[:kind]
    when :bars
      width = [ (WIDTH - PAD[:left] - PAD[:right]) / count.to_f * 0.6, 24 ].min
      zero = y.(0)
      bars = points.reject { |_px, py| py == zero }.map do |px, py|
        tag.path(d: chart_bar(px - width / 2, width, zero, py), class: "bar #{series[:tone]}")
      end
      safe_join(bars)
    else
      # nil breaks the line, so a week the report lacks is a gap, not a slope.
      runs = series[:values].each_with_index.chunk_while { |(a, _), (b, _)| a && b }.map do |run|
        run.filter_map { |value, i| "#{x.(i).round(1)},#{y.(value)}" if value }
      end
      lines = runs.reject(&:empty?).map do |run|
        next tag.polyline(points: run.join(" "), class: "line #{series[:tone]}") if run.many?

        # A week on its own has no line to sit on: a short dash for a target,
        # a small dot for a value.
        px, py = run.first.split(",").map(&:to_f)
        if series[:kind] == :reference
          tag.line(x1: px - 10, x2: px + 10, y1: py, y2: py, class: "line #{series[:tone]}")
        else
          tag.circle(cx: px, cy: py, r: 3, class: "dot #{series[:tone]}")
        end
      end
      dot = (tag.circle(cx: points.last[0], cy: points.last[1], r: 4, class: "dot #{series[:tone]}") if series[:kind] == :line && points.any?)
      safe_join([ *lines, dot ].compact)
    end
  end

  # A bar from the zero line, square there and rounded at its value.
  def chart_bar(left, width, zero, top)
    r = [ 4, width / 2, (top - zero).abs ].min
    dir = top < zero ? 1 : -1
    right = left + width
    "M#{left.round(1)},#{zero}V#{(top + dir * r).round(1)}Q#{left.round(1)},#{top} #{(left + r).round(1)},#{top}" \
      "H#{(right - r).round(1)}Q#{right.round(1)},#{top} #{right.round(1)},#{(top + dir * r).round(1)}V#{zero}Z"
  end

  # One invisible column per week, wider than any mark, whose title is the
  # tooltip: every series' value that week.
  def chart_hover_columns(dates, series, x)
    slot = (WIDTH - PAD[:left] - PAD[:right]) / [ dates.size - 1, 1 ].max.to_f
    dates.each_with_index.map do |date, i|
      lines = series.filter_map { |s| "#{s[:name]}: #{number_with_delimiter(s[:values][i].to_f.round)}" if s[:values][i] }
      tag.rect(tag.title([ date.strftime("%b %-d, %Y"), *lines ].join("\n")),
               x: (x.(i) - slot / 2).round(1), y: PAD[:top], width: slot.round(1), height: HEIGHT - PAD[:top] - PAD[:bottom], class: "hit")
    end
  end

  def chart_legend(series)
    tag.ul(class: "legend") do
      safe_join(series.map { |s| tag.li(safe_join([ tag.span(class: "key #{s[:kind]} #{s[:tone]}"), s[:name] ])) })
    end
  end

  # 1,500 → 1.5K, 2,000,000 → 2M.
  def compact_number(value)
    number_to_human(value, format: "%n%u", precision: 2, significant: true,
                           units: { unit: "", thousand: "K", million: "M", billion: "B" })
  end
end
