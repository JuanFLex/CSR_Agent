module Csr
  # Where a key stood in one report week: its buffer from the Buffer Readiness
  # report and its demand from the Demand Comparison report. Snapshots are
  # pruned to two (Snapshot::KEEP_GOOD), so this is what the week-over-week
  # charts read. Written when a load activates, one source's columns at a time.
  class WeeklyPosition < ApplicationRecord
    belongs_to :part_key, inverse_of: :weekly_positions

    scope :for_keys, ->(keys) { where(part_key_id: keys) }

    # Writes one source's columns for a week and leaves the other source's
    # alone, so a reloaded week replaces only what that load knows.
    def self.record!(rows, columns)
      rows.each_slice(SourceIngest::INSERT_BATCH) do |slice|
        upsert_all(slice, unique_by: %i[part_key_id week], update_only: columns)
      end
    end
  end
end
