module Csr
  # For a source the ETL fills with a bulk load that is not one transaction: a
  # load this recent may still be under way, so it is left for the next poll.
  # A forced run does not wait. Its staging table tells its own `age`.
  #
  # ponytail: a fixed wait, on the assumption that the package finishes all
  # its sheets within it. If it ever runs longer, stamp one start time on
  # every table and compare those instead.
  module WaitsForEtl
    SETTLE = 30.minutes

    def call
      age = staging.age unless @force
      return super if age.nil? || age >= SETTLE

      SourceIngest::Result.new(status: :skipped, snapshot: Snapshot.current(source_type, region: @region),
                               message: "#{staging.table_name} was loaded #{(age / 60).round} min ago; waiting for the ETL to finish")
    # The age is read before the load's own rescue, so a reporting server that
    # does not answer is a failed load here too: logged by the job, the
    # previous snapshot still serving.
    rescue StandardError => e
      SourceIngest::Result.new(status: :failed, message: e.message)
    end
  end
end
