module Csr
  # Polls CSR_OSOR_AMERICAS and ingests it when its watermark moves.
  #
  # OSOR is reloaded twice a day, so this runs on a schedule and exits cheaply
  # when there is nothing new — the watermark check is a single MAX() query.
  class OsorIngestJob < ApplicationJob
    queue_as :default

    def perform(region: DEFAULT_REGION, force: false)
      result = Osor::Ingest.new(region: region, force: force).call

      case result.status
      when :activated then Rails.logger.info("[csr.osor] #{result.message}")
      when :skipped   then Rails.logger.debug("[csr.osor] #{result.message}")
      when :failed    then Rails.logger.error("[csr.osor] load rejected: #{result.message}")
      end

      result
    end
  end
end
