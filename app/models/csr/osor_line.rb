module Csr
  # One open order line, as reported by OSOR. Mirrors CSR_OSOR_AMERICAS but
  # speaks the build book's vocabulary; Csr::Osor::ColumnMap holds the
  # translation.
  class OsorLine < ApplicationRecord
    extend SelectableColumns

    # Every column the open-orders table can show, in display order. tOSOR puts
    # all of these in front of the Excel's user; the portal shows the first
    # handful until the reader asks for more.
    COLUMNS = {
      cpo_ref: "CPO", so_ref: "SO", po: "PO", po_pos: "PO Pos", seq: "Seq",
      cpn: "CPN", mpn: "MPN", fpn: "FPN", description: "Description", manufacturer: "Manufacturer",
      bp_name: "Customer", sold_to_bp: "Sold-to", ship_address: "Ship-to",
      baan_ordered: "Qty", spq: "SPQ", spq_ordered: "SPQ / Order", moq: "MOQ",
      pdd: "Need (PDD)", cdd: "ETD (CDD)", promdd: "PROMDD", previous_cdd: "Previous CDD",
      days_previous_cdd: "Days prev. CDD", cust_req_date: "Cust req date",
      cust_rec_date: "Cust rec date", order_date: "Order date",
      so_status: "SO status", so_type: "SO type", dates_condition: "Dates status",
      error_condition: "Error condition", load_code: "Load", load_line_status: "Load line status",
      load_general: "Load general", load_spq_mismatch: "Load SPQ mismatch",
      blocked: "Blocked", block_codes: "Block codes", inv_status: "Inv status",
      so_whs: "SO WHS", whs: "INV WHS", inv_whs: "Inv WHS2",
      stock: "Stock", block_qty: "Block", free_qty: "Free",
      price: "Price", amount: "Amount", amount_qty_price: "Amount = Qty x Price",
      amount_discrepancy: "Amount discrepancy",
      po_qty: "PO qty", po_price: "PO price", po_confirm_date: "PO confirm date",
      po_change_date: "PO change date", po_activity: "PO activity", po_ref_a: "PO Ref A",
      ppv: "PPV", mauc_price: "MAUC price", so_ppv_price: "SO PPV price", so_ppv_total: "SO PPV total",
      project: "Project", so_urgent: "SO urgent", ref_a: "Reference A", ref_b: "Ref B",
      kinaxis_unconfirmed: "Kinaxis unconfirmed", kinaxis_confirmed: "Kinaxis confirmed",
      source_last_update: "Source updated"
    }.freeze

    DEFAULT_COLUMNS = %i[cpo_ref so_ref po mpn baan_ordered pdd cdd so_status].freeze

    # The two columns tOSOR computes rather than stores. They stay virtual, so
    # a snapshot holds what the source said and nothing else.
    attribute :amount_qty_price, :decimal
    attribute :amount_discrepancy, :decimal

    belongs_to :snapshot, inverse_of: :osor_lines
    belongs_to :part_key, optional: true, inverse_of: :osor_lines

    scope :in_snapshot, ->(snapshot) { where(snapshot: snapshot) }
    scope :for_keys, ->(keys) { where(part_key_id: keys) }
    scope :missed, -> { where(miss: true) }

    def cpo_ref = [ cpo, cpo_pos ].compact_blank.join("-")
    def so_ref  = [ so, so_pos ].compact_blank.join("-")

    def amount_qty_price
      return nil if baan_ordered.nil? || price.nil?

      baan_ordered * price
    end

    def amount_discrepancy
      return nil if amount.nil? || amount_qty_price.nil?

      amount - amount_qty_price
    end

    # A line is late when the date we committed lands after the date the
    # customer needs it (CDD > PDD). Both must be present: an unconfirmed line
    # is not a miss, it is simply unconfirmed.
    def self.miss?(pdd, cdd)
      return false if pdd.blank? || cdd.blank?

      cdd > pdd
    end
  end
end
