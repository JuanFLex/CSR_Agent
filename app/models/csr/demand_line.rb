module Csr
  # One part's row of the Demand Comparison report: how much its demand moved
  # between last week's snapshot and this week's, inside its lead time and in
  # total.
  class DemandLine < ApplicationRecord
    belongs_to :snapshot, inverse_of: :demand_lines
    belongs_to :part_key, optional: true, inverse_of: :demand_lines

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }
    scope :for_keys, ->(keys) { where(part_key_id: keys) }
  end
end
