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
      shortage_qty:       "Short qty",
      owner_name:         "Owner",
      owner_role:         "Owner role",
      owner_email:        "Owner email",
      age_current_owner:  "Days with owner",
      customer:           "Global customer",
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

    # Upper bound, in weeks to the need date, of every tier but the last (T4).
    TIERS = { "T0" => 4, "T1" => 8, "T2" => 12, "T3" => 20 }.freeze

    # How close the shortage is, from the earliest need date still ahead.
    # ponytail: nil (every order past due, or none at all) is the most urgent
    # tier; Alejandro may want orderless FETs untiered — then return nil here.
    def self.tier(need_date, today: Date.current)
      return "T0" if need_date.nil?

      weeks = (need_date.to_date - today).to_i / 7.0
      TIERS.find { |_tier, limit| weeks < limit }&.first || "T4"
    end

    # The one severity flag CSR_FET actually carries. Priority is not in the
    # table; it is computed from the orders (see .tier).
    def line_down? = line_down == "Y"

    # ponytail: CSR_FET signs a shortage negative; the stored value keeps the
    # source's sign and only the reader sees the quantity short.
    def shortage_qty = super&.abs
  end
end
