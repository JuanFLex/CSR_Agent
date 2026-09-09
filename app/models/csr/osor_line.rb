module Csr
  # One open order line, as reported by OSOR. Mirrors CSR_OSOR_AMERICAS but
  # speaks the build book's vocabulary; Csr::Osor::ColumnMap holds the
  # translation.
  class OsorLine < ApplicationRecord
    belongs_to :snapshot, inverse_of: :osor_lines
    belongs_to :part_key, optional: true, inverse_of: :osor_lines

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }
    scope :for_keys, ->(keys) { where(part_key_id: keys) }
    scope :missed, -> { where(miss: true) }

    # A line is late when the date we committed lands after the date the
    # customer needs it (CDD > PDD). Both must be present: an unconfirmed line
    # is not a miss, it is simply unconfirmed.
    def self.miss?(pdd, cdd)
      return false if pdd.blank? || cdd.blank?

      cdd > pdd
    end
  end
end
