module Api
  # GET /api/orders — the OSOR lines behind the numbers on /api/status.
  class OrdersController < BaseController
    def index
      limit = Csr::SearchRequest::MAX_LINES
      lines = search_request.lines(limit: limit + 1).to_a
      truncated = lines.size > limit
      lines = lines.first(limit)

      render_envelope(
        count: lines.size,
        truncated: truncated,
        orders: lines.map { |l|
          {
            cpn: l.cpn, mpn: l.mpn, fpn: l.fpn,
            customer: l.bp_name, cpo: l.cpo, cpo_pos: l.cpo_pos,
            so: l.so, so_pos: l.so_pos, po: l.po,
            baan_ordered: l.baan_ordered, pdd: l.pdd, cdd: l.cdd,
            miss: l.miss, so_status: l.so_status, dates_condition: l.dates_condition
          }
        }
      )
    end
  end
end
