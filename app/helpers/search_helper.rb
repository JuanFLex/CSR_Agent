module SearchHelper
  # The dimensions the keys table shows. A key with more than one value in any
  # of them is where the Excel would have shown just one.
  KEY_DIMENSIONS = %i[fpn customer site].freeze

  def spans_many?(context)
    context.values_at(*KEY_DIMENSIONS).any? { |values| Array(values).many? }
  end

  # Part numbers, order numbers and references read as codes, not prose.
  MONO_COLUMNS = %i[
    escalation_number mpn cpn fpn cpo_ref so_ref po po_pos seq po_ref_a ref_a ref_b
  ].freeze

  # One table cell, formatted by what the value is rather than by a list that
  # would have to be kept in step with the column set.
  def column_cell(record, column)
    value = record.public_send(column)

    case value
    when nil                 then "—"
    when Time, Date          then short_date(value)
    # Quantities are whole; prices are not. Truncating both to an integer is
    # how a 0.44 unit price reads as zero.
    when Numeric             then number_with_precision(value, precision: 4, delimiter: ",", strip_insignificant_zeros: true)
    else
      MONO_COLUMNS.include?(column) ? tag.code(value) : value.to_s
    end
  end

  # Month and day, plus the year when it is not this one, so a past-due or
  # next-year line cannot pass for this year's.
  def short_date(time)
    return "—" unless time

    date = time.to_date
    l(date, format: date.year == Date.current.year ? :short : :short_with_year)
  end

  def order_ref(number, position)
    [ number, position ].compact_blank.join("-")
  end

  # Whole days between need and commit. Zero when a line is late only by time
  # of day: the miss rule compares timestamps, as the Excel does.
  def slip_days(line)
    (line.cdd.to_date - line.pdd.to_date).to_i
  end

  # Late / On time follows the miss rule (CDD > PDD). A line with no CDD is
  # unconfirmed, not a third risk tier — nobody has defined one yet.
  def risk_pill(line)
    if line.miss
      days = slip_days(line)
      tag.span(days.positive? ? "Late +#{days}d" : "Late", class: "pill late")
    elsif line.cdd
      tag.span("On time", class: "pill ok")
    else
      tag.span("Unconfirmed", class: "pill unconfirmed")
    end
  end

  # The Summary bullets. The same list is the body of "Copy to email", so the
  # card and the email cannot say different things.
  def summary_points(search, summary, context)
    points = []

    points << if summary[:misses].positive?
      safe_join([ tag.strong("#{summary[:misses]} of #{summary[:open_lines]}", class: "bad"), " open lines are late (CDD > PDD)." ])
    else
      "None of the #{summary[:open_lines]} open lines is late."
    end

    if (slip = search.worst_slip)
      days = slip_days(slip)
      points << safe_join([
        "Largest slip: CPO ", tag.code(order_ref(slip.cpo, slip.cpo_pos)),
        " committed #{short_date(slip.cdd)} for a #{short_date(slip.pdd)} need (",
        tag.strong(days.positive? ? "+#{days} days" : "same day, later time", class: "bad"), ")."
      ])
    end

    if summary[:unconfirmed].positive?
      points << "#{pluralize(summary[:unconfirmed], "line")} with no committed date yet."
    end

    if (escalations = search.escalations).any?
      down = escalations.count(&:line_down?)
      points << safe_join([
        tag.strong(pluralize(escalations.size, "open escalation")), " on these MPNs",
        down.positive? ? safe_join([ ", ", tag.strong("#{down} with the line down", class: "bad") ]) : "", "."
      ])
    end

    spanning = context.count { |_id, ctx| spans_many?(ctx) }
    if spanning.positive?
      points << safe_join([ tag.strong(pluralize(spanning, "key")), " #{spanning == 1 ? "spans" : "span"} more than one FPN, customer or plant." ])
    end

    points
  end

  def summary_email_body(search, points)
    snapshot = search.snapshot
    [
      "#{search.label} #{search.value}",
      "",
      *points.map { |point| "- #{Nokogiri::HTML.fragment(point.to_s).text}" },
      "",
      "Source: #{snapshot.source_file}, snapshot ##{snapshot.id}, updated #{snapshot.fresh_as_of&.strftime("%b %d, %H:%M")}"
    ].join("\n")
  end
end
