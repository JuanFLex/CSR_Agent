module Csr
  # One escalation (FET), as reported by CSR_FET.
  #
  # An escalation carries no CPN, so it cannot resolve to a CPN|MPN key the way
  # an order line does: the same MPN can belong to several keys, and picking one
  # would be the Excel's mistake again. It keeps the normalized MPN and FPN it
  # was raised against, and the join happens at read time.
  class Escalation < ApplicationRecord
    extend SelectableColumns

    belongs_to :snapshot, inverse_of: :escalations

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }

    # Every escalation raised against the MPN of any of these keys.
    scope :for_keys, ->(keys) { where(mpn: PartKey.where(id: keys).select(:mpn)) }

    # Every column the escalations panel can show, in display order, and the
    # subset it shows until the user says otherwise. The flags column
    # (line down, allocation) is not here: it is severity, always on.
    COLUMNS = {
      escalation_number:  "FET #",
      mpn:                "MPN",
      fpn:                "FPN",
      escalation_type:    "Type",
      escalation_status:  "Status",
      date_opened:        "Opened",
      days_open:          "Days open",
      shortage_qty:       "Shortage",
      owner_name:         "Owner",
      owner_role:         "Owner role",
      owner_email:        "Owner email",
      age_current_owner:  "Days with owner",
      customer:           "Customer",
      manufacturer:       "Manufacturer",
      supplier:           "Supplier",
      description:        "Description",
      facility:           "Facility",
      region_code:        "Region",
      escalation_group:   "Group",
      reason_code:        "Reason",
      site_revenue_impact: "Revenue impact",
      impact_date:        "Impact date",
      updated_date:       "Updated",
      last_action_comments: "Last action"
    }.freeze

    DEFAULT_COLUMNS = %i[escalation_number mpn escalation_type date_opened days_open shortage_qty owner_name].freeze

    # The one severity flag CSR_FET actually carries. Priority (T0-T3) lives in
    # the escalation spreadsheet, not in this table.
    def line_down? = line_down == "Y"
  end
end
