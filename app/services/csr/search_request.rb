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
    MAX_LINES = 500

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

    def lines(limit: MAX_LINES)
      return OsorLine.none if snapshot.nil?

      OsorLine.in_snapshot(snapshot)
              .for_keys(part_keys.select(:id))
              .order(:cdd, :so, :so_pos)
              .limit(limit)
    end
  end
end
