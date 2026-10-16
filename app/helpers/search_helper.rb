module SearchHelper
  # The dimensions the keys table shows. A key with more than one value in any
  # of them is where the Excel would have shown just one.
  KEY_DIMENSIONS = %i[fpn customer site].freeze

  def spans_many?(context)
    context.values_at(*KEY_DIMENSIONS).any? { |values| Array(values).many? }
  end

  KEY_DIMENSION_LABELS = { fpn: "FPN", customer: "Sold-to", site: "Plant" }.freeze

  # Each key and dimension holding more than one value, for the alert over the
  # keys table: [key, label, values]. Two keys with different FPNs is normal;
  # one key with two is the conflict.
  def key_conflicts(keys, context)
    keys.flat_map do |key|
      ctx = context[key.id] || {}
      KEY_DIMENSIONS.filter_map do |dimension|
        values = Array(ctx[dimension])
        [ key, KEY_DIMENSION_LABELS.fetch(dimension), values ] if values.many?
      end
    end
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
  # unconfirmed, not a risk: its age since the order was created shows how
  # much of the 5 days to confirm is gone.
  def risk_pill(line)
    if line.miss
      days = slip_days(line)
      tag.span(days.positive? ? "Late +#{days}d" : "Late", class: "pill late")
    elsif line.cdd
      tag.span("On time", class: "pill ok")
    else
      age = line.order_date && (Date.current - line.order_date.to_date).to_i
      tag.span(age ? "Unconfirmed +#{age}d" : "Unconfirmed", class: "pill unconfirmed")
    end
  end

  # A key that can break between its CPN and its MPN, and nowhere else, so a
  # long one gives the table room instead of pushing its last columns out.
  def key_code(key)
    tag.code(safe_join([ tag.span("#{key.cpn}|"), tag.wbr, tag.span(key.mpn) ]))
  end

  # A balance as a multiple of the safety stock: 0.5× is half the target.
  def buffer_ratio(value)
    "#{number_with_precision(value, precision: 2, strip_insignificant_zeros: true)}×"
  end

  # Where a key's buffer stands. "No target" is a part with no safety stock
  # agreed, which the workbook shows as a 0 and flags; "—" is a part the
  # buffer report does not carry at all.
  def buffer_pill(position)
    return "—" if position.nil?
    return tag.span("No target", class: "pill unconfirmed") if position.no_target?

    lowest = buffer_ratio(position.min_vs_ss)
    position.below_target? ? tag.span("Below target · #{lowest}", class: "pill late") : tag.span("Covered · #{lowest}", class: "pill ok")
  end

  # A commit balance is negative when short; it is read as that many pieces.
  def short_qty(balance)
    number_with_delimiter(balance.abs.to_i)
  end

  # Where a key's commit stands: the most pieces of forecast left without a
  # commitment in any week. "—" is a part the commit report does not carry.
  def commit_pill(position)
    return "—" if position.nil?

    position.short? ? tag.span("Short · #{short_qty(position.min_balance)}", class: "pill late") : tag.span("Covered", class: "pill ok")
  end

  # The Summary bullets. The same list is the body of "Copy to email", so the
  # card and the email cannot say different things.
  def summary_points(search, summary, context)
    points = []

    points << if summary[:open_lines] == 1
      summary[:misses].positive? ? safe_join([ tag.strong("The only open line is late", class: "bad"), " (CDD > PDD)." ]) : "The only open line is on time."
    elsif summary[:misses].positive?
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
        tag.strong(pluralize(escalations.size, "open escalation")), " on these #{search.search_type == "mpn" ? "MPNs" : "FPNs"}",
        down.positive? ? safe_join([ ", ", tag.strong("#{down} with the line down", class: "bad") ]) : "", "."
      ])
    end

    targeted = search.buffer.values.reject(&:no_target?)
    if targeted.any?
      below = targeted.select(&:below_target?)
      points << if below.any?
        safe_join([
          "Buffer: ", tag.strong("#{below.size} of #{pluralize(targeted.size, "key")}", class: "bad"),
          " with a safety stock #{below.size == 1 ? "drops" : "drop"} below it (lowest #{buffer_ratio(below.map(&:min_vs_ss).min)})."
        ])
      else
        "Buffer: #{targeted.size == 1 ? "the key" : "all #{targeted.size} keys"} with a safety stock #{targeted.size == 1 ? "stays" : "stay"} at or above it."
      end
    end

    committed = search.commit.values
    if committed.any?
      short = committed.select(&:short?)
      points << if short.any?
        safe_join([
          "Commit: ", tag.strong("#{short.size} of #{pluralize(committed.size, "key")}", class: "bad"),
          " #{short.size == 1 ? "runs" : "run"} short of the forecast (up to #{short_qty(short.map(&:min_balance).min)} pcs, from #{short_date(short.map(&:short_from).min)})."
        ])
      else
        "Commit: #{committed.size == 1 ? "the key is" : "all #{committed.size} keys are"} covered against the forecast."
      end
    end

    spanning = context.count { |_id, ctx| spans_many?(ctx) }
    if spanning.positive?
      points << safe_join([ tag.strong(pluralize(spanning, "key")), " #{spanning == 1 ? "spans" : "span"} more than one FPN, sold-to or plant." ])
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
