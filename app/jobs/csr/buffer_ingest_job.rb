module Csr
  # Reloads CS_tempTrendBufferReadinessProjection into a snapshot when the ETL
  # has refilled it.
  #
  # The Buffer Readiness sheet is weekly. This polls hourly and exits on a
  # single MAX(loaded_at) when nothing changed, so a load is picked up without
  # anyone having to say which day it lands.
  class BufferIngestJob < ApplicationJob
    queue_as :default

    def perform(region: DEFAULT_REGION, force: false)
      result = Buffer::Ingest.new(region: region, force: force).call

      case result.status
      when :activated then Rails.logger.info("[csr.buffer] #{result.message}")
      when :skipped   then Rails.logger.debug("[csr.buffer] #{result.message}")
      when :failed    then Rails.logger.error("[csr.buffer] load rejected: #{result.message}")
      end

      result
    end
  end
end
