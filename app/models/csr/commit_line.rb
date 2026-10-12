module Csr
  # One week of one part's commit balance, from the "Balance" row of the
  # Customer Commitment report: the forecast not yet covered by a commitment,
  # accumulated up to that week. 0 is covered, and a negative number is that
  # many pieces short. It is never positive.
  class CommitLine < ApplicationRecord
    belongs_to :snapshot, inverse_of: :commit_lines
    belongs_to :part_key, optional: true, inverse_of: :commit_lines

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }
    scope :for_keys, ->(keys) { where(part_key_id: keys) }
  end
end
