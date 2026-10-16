module Csr
  # Parses what arrives from the search form or the API into something the
  # resolver can act on, and carries the labels the UI needs.
  #
  # INPUT_PANEL offers five ways in. They are not interchangeable: CPN and MPN
  # identify parts, SO and CPO identify orders, and the resolver reaches the keys
  # by a different route for each.
  class SearchRequest
    TYPES = {
      "cpn"      => "CPN",
      "mpn"      => "MPN",
      "cpo_line" => "CPO+Line",
      "so"       => "SO",
      "fpn"      => "FPN"
    }.freeze

    DEFAULT_TYPE = "cpn"
    LINES_PER_PAGE = 50

    attr_reader :search_type, :value, :region

    def self.options_for_select
      TYPES.map { |value, label| [ label, value ] }
    end

    def initialize(params = {})
      requested = params[:search_type].to_s.downcase
      @search_type = TYPES.key?(requested) ? requested : DEFAULT_TYPE
      @value = params[:value].to_s.strip
      @region = params[:region].presence || DEFAULT_REGION
    end

    def blank? = @value.blank?
    def label  = TYPES.fetch(@search_type)

    def snapshot
      return @snapshot if defined?(@snapshot)

      @snapshot = Snapshot.current("osor", region: @region)
    end

    def part_keys
      @part_keys ||= KeyResolver.new(
        search_type: @search_type, value: @value, region: @region, snapshot: snapshot
      ).call
    end

    def summary
      @summary ||= ExecutionSummary.new(part_keys, snapshot: snapshot).call
    end

    def context
      @context ||= KeyContext.new(part_keys, snapshot: snapshot).call
    end

    # Where each key's buffer stands, from the buffer snapshot. It has its own
    # cadence (weekly), so it is never read through the OSOR one.
    def buffer
      @buffer ||= BufferSummary.new(part_keys, snapshot: sources["buffer"]).call
    end

    # Where each key's commit stands, from the commit snapshot. Weekly too.
    def commit
      @commit ||= CommitSummary.new(part_keys, snapshot: sources["commit"]).call
    end

    # The active snapshot of every source, nil for one never loaded — the
    # freshness chips. One query rather than one per source.
    def sources
      @sources ||= begin
        active = Snapshot.active.where(region: @region).order(:activated_at).index_by(&:source_type)
        Snapshot::SOURCE_TYPES.index_with { |type| active[type] }
      end
    end

    # The open escalations of what was searched. FlexWare raises one FET per
    # FPN, so a FET belongs to the FPNs on these orders; matching by MPN would
    # add another customer's FETs that merely share the part (+29% measured).
    # Only an MPN search asks for everything raised against the part.
    def escalations
      @escalations ||= begin
        snapshot = sources["escalation"]
        matched = @search_type == "mpn" ? Escalation.for_keys(part_keys) : Escalation.where(fpn: scoped_lines.select(:fpn))
        snapshot ? matched.in_snapshot(snapshot).order(:mpn, :date_opened) : Escalation.none
      end
    end

    # The earliest PDD still ahead on the open orders of each escalation's FPN,
    # which is what the tier measures. An FPN whose orders are all past due maps
    # to nil; one with no open order at all is absent.
    def need_dates
      @need_dates ||= begin
        today = Date.current
        rows = snapshot ? OsorLine.in_snapshot(snapshot).where(fpn: escalations.map(&:fpn)).pluck(:fpn, :pdd) : []
        rows.group_by(&:first).transform_values do |pairs|
          pairs.filter_map { |_fpn, pdd| pdd if pdd && pdd.to_date >= today }.min
        end
      end
    end

    # One page of the open lines, earliest commit first. limit: nil is all of
    # them, for the export.
    def lines(limit: LINES_PER_PAGE, page: 1)
      scoped_lines.order(:cdd, :so, :so_pos).limit(limit).offset(limit && (page - 1) * limit)
    end

    # The late line with the widest gap between commit and need.
    def worst_slip
      return @worst_slip if defined?(@worst_slip)

      @worst_slip = scoped_lines.missed.order(Arel.sql("cdd - pdd DESC"), :so, :so_pos).first
    end

    private

    def scoped_lines
      return OsorLine.none if snapshot.nil?

      OsorLine.in_snapshot(snapshot).for_keys(part_keys.select(:id))
    end
  end
end
