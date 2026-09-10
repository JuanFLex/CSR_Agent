module Csr
  # Reloads CSR_FET into a snapshot when the escalation ETL has moved.
  #
  # That ETL runs every 3 hours. This polls hourly and exits cheaply when
  # nothing changed, so a load is picked up within the hour of landing rather
  # than whenever a fixed 3-hour schedule happens to fall.
  class FetIngestJob < ApplicationJob
    queue_as :default

    def perform(region: DEFAULT_REGION, force: false)
      result = Fet::Ingest.new(region: region, force: force).call

      case result.status
      when :activated then Rails.logger.info("[csr.fet] #{result.message}")
      when :skipped   then Rails.logger.debug("[csr.fet] #{result.message}")
      when :failed    then Rails.logger.error("[csr.fet] load rejected: #{result.message}")
      end

      result
    end
  end
end
