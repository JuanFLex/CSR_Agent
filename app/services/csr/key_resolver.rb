module Csr
  # Turns what a CSR types into the set of Keys it refers to.
  #
  # This is KEY_LIST!A2 from the workbook. The important property, and the one
  # the Excel had to fight its formulas to get, is that the result is one row per
  # unique CPN|MPN — never one row per order line. A CPN carrying two MPNs
  # legitimately produces two rows; the same CPN|MPN across six order lines
  # produces one row with Open Lines = 6.
  class KeyResolver
    def initialize(search_type:, value:, snapshot:, region: DEFAULT_REGION)
      @search_type = search_type.to_s.downcase
      @value = value.to_s.strip
      @region = region
      @snapshot = snapshot
    end

    def call
      return PartKey.none if @value.blank? || @snapshot.nil?
      return PartKey.none unless SearchRequest::TYPES.key?(@search_type)

      case @search_type
      when "cpn" then PartKey.where(region: @region).by_cpn(@value)
      when "mpn" then PartKey.where(region: @region).by_mpn(@value)
      when "fpn"      then keys_from_lines(fpn: PartKey.normalize(@value))
      when "so"       then keys_from_lines(so: @value)
      when "cpo_line" then keys_from_lines(**cpo_conditions)
      end
    end

    # INPUT_PANEL!E4/E5 split the typed value at the first hyphen: everything
    # before it is the CPO, everything after is the line. A value with no hyphen
    # is a whole CPO, which is the more common thing to paste.
    def cpo_conditions
      cpo, cpo_pos = @value.split("-", 2).map { |part| part&.strip.presence }
      cpo_pos.present? ? { cpo: cpo, cpo_pos: cpo_pos } : { cpo: cpo }
    end

    private

    # SO, CPO and FPN live on the order line, not on the key, so these search
    # types reach the keys through the lines of the active snapshot.
    def keys_from_lines(**conditions)
      key_ids = OsorLine.in_snapshot(@snapshot).where(**conditions).distinct.select(:part_key_id)
      PartKey.where(region: @region, id: key_ids)
    end
  end
end
