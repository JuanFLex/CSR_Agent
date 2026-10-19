module Csr
  # A source that arrives wide and is stored long: one row per part with a
  # column per week becomes one line per part and week.
  #
  # Buffer and Commit both reach the ETL this way, as sheets of
  # CS_Trend_Forecast.xlsx copied column by column, and both lose the dates of
  # their header row on the way in. The weeks are consecutive Saturdays, so
  # the first one is all that is needed, and the workbook's vertical sheet
  # still has it (`calendar`).
  #
  # A subclass names its `column_map`, its `line_model` and the attribute a
  # week's value is stored under.
  class WeeklyIngest < SourceIngest
    # The dates come from a third table loaded in the same run, so the wait
    # covers it too.
    include WaitsForEtl

    ROW_BATCH = 200

    def initialize(staging:, calendar: Reporting::VerticalCommitStaging, **options)
      super(**options)
      @staging = staging
      @calendar = calendar
    end

    private

    attr_reader :staging

    def load_rows(snapshot)
      first_week = @calendar.first_week
      raise "#{@calendar.table_name} gave #{first_week.inspect} as the first week, which is not a Saturday" unless first_week&.saturday?
      raise "#{staging.table_name} no longer has its columns where the map reads them" unless staging.layout_ok?

      count = staging.count
      inserted = 0
      rejected = 0

      staging.rows.each_slice(ROW_BATCH) do |rows|
        attribute_sets = rows.map { |row| column_map.cast(row) }
        key_ids, key_values = resolve_part_keys(attribute_sets)
        now = Time.current

        records = attribute_sets.zip(key_values).flat_map do |attrs, key_value|
          weeks = attrs.delete(:weeks)
          rejected += weeks.size if key_value.nil?
          line = attrs.merge(snapshot_id: snapshot.id, part_key_id: key_ids[key_value], created_at: now, updated_at: now)

          weeks.each_with_index.map { |value, week| line.merge(:bucket_date => first_week + 7 * week, value_attribute => value) }
        end

        records.each_slice(INSERT_BATCH) { |slice| line_model.insert_all!(slice) }
        inserted += records.size
      end

      snapshot.update!(row_count: inserted, rejected_count: rejected)

      # A table refilled while it was being read gives a mix of two loads.
      raise "#{staging.table_name} changed while it was being read" unless staging.count == count
    end

    def activation_message(snapshot)
      "Activated #{snapshot.row_count} #{source_type} weeks (#{snapshot.rejected_count} without a key)"
    end
  end
end
