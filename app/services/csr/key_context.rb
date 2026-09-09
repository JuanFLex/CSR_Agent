module Csr
  # The FPNs, customers, ship-tos and plants a key actually spans, gathered from
  # its order lines.
  #
  # The Excel had to pick one of each (List.First) because a lookup returns a
  # single cell, which is how it ends up showing one ship-to's situation when
  # asked about another. Nothing forces that choice here, so the answer is the
  # whole set — and where the set has more than one member, that is itself worth
  # seeing rather than hiding.
  class KeyContext
    DIMENSIONS = {
      fpn: :fpn, customer: :bp_name, ship_to: :ship_address, site: :so_whs
    }.freeze

    def initialize(part_keys, snapshot:)
      @part_keys = part_keys
      @snapshot = snapshot
    end

    # => { part_key_id => { fpn: [...], customer: [...], ship_to: [...], site: [...] } }
    def call
      return {} if @snapshot.nil?

      rows = OsorLine.in_snapshot(@snapshot)
                     .for_keys(@part_keys.select(:id))
                     .distinct
                     .pluck(:part_key_id, *DIMENSIONS.values)

      rows.each_with_object(Hash.new { |h, k| h[k] = empty_context }) do |row, acc|
        id, *values = row
        DIMENSIONS.keys.each_with_index do |dimension, index|
          value = values[index]
          acc[id][dimension] << value if value.present?
        end
      end.transform_values { |ctx| ctx.transform_values { |set| set.to_a.sort } }
    end

    private

    def empty_context = DIMENSIONS.keys.index_with { Set.new }
  end
end
