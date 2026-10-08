module Csr
  # One week of one part's buffer projection, as reported by
  # CSR_BUFFER_READINESS: the "Balance vs SS (Buffer Stock)" row of the Buffer
  # Readiness report, which is the projected balance as a multiple of the
  # safety stock. 1 is exactly on target, below 1 is into the buffer, below 0
  # is short.
  #
  # A row whose safety stock is 0 has no target to measure against, and the
  # report writes 0 in every one of its weeks. That 0 means "not applicable",
  # not "empty buffer"; Csr::BufferSummary is where the two are told apart.
  class BufferLine < ApplicationRecord
    belongs_to :snapshot, inverse_of: :buffer_lines
    belongs_to :part_key, optional: true, inverse_of: :buffer_lines

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }
    scope :for_keys, ->(keys) { where(part_key_id: keys) }
  end
end
