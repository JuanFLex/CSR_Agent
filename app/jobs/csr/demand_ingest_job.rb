module Csr
  # Reloads CSR_DemandComparison into a snapshot when the ETL has refilled it.
  #
  # The report is generated on Mondays. This polls hourly like the others and
  # exits on a single MAX(loaded_at) when nothing changed.
  class DemandIngestJob < ApplicationJob
    queue_as :default

    def perform(region: DEFAULT_REGION, force: false)
      result = Demand::Ingest.new(region: region, force: force).call

      case result.status
      when :activated then Rails.logger.info("[csr.demand] #{result.message}")
      when :skipped   then Rails.logger.debug("[csr.demand] #{result.message}")
      when :failed    then Rails.logger.error("[csr.demand] load rejected: #{result.message}")
      end

      result
    end
  end
end
