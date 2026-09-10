module Csr
  # One escalation (FET), as reported by CSR_FET.
  #
  # An escalation carries no CPN, so it cannot resolve to a CPN|MPN key the way
  # an order line does: the same MPN can belong to several keys, and picking one
  # would be the Excel's mistake again. It keeps the normalized MPN and FPN it
  # was raised against, and the join happens at read time.
  class Escalation < ApplicationRecord
    belongs_to :snapshot, inverse_of: :escalations

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }

    # Every escalation raised against the MPN of any of these keys.
    scope :for_keys, ->(keys) { where(mpn: PartKey.where(id: keys).select(:mpn)) }

    def open? = escalation_status.to_s.casecmp("closed") != 0

    # The one severity flag CSR_FET actually carries. Priority (T0-T3) lives in
    # the escalation spreadsheet, not in this table.
    def line_down? = line_down == "Y"
  end
end
