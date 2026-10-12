module Csr
  # Reloads CSR_CustomerCommitment into a snapshot when the ETL has refilled it.
  #
  # The Customer Commitment sheet is weekly. This polls hourly and exits on a
  # single MAX(loaded_at) when nothing changed, so a load is picked up without
  # anyone having to say which day it lands.
  class CommitIngestJob < ApplicationJob
    queue_as :default

    def perform(region: DEFAULT_REGION, force: false)
      result = Commit::Ingest.new(region: region, force: force).call

      case result.status
      when :activated then Rails.logger.info("[csr.commit] #{result.message}")
      when :skipped   then Rails.logger.debug("[csr.commit] #{result.message}")
      when :failed    then Rails.logger.error("[csr.commit] load rejected: #{result.message}")
      end

      result
    end
  end
end
