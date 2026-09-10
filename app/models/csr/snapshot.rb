module Csr
  # One load of one source. Data is never mutated in place: reloading means
  # inserting a new snapshot and flipping it to active once it passes its
  # guards, so readers never see a half-loaded table and last week's numbers
  # stay available for comparison.
  class Snapshot < ApplicationRecord
    SOURCE_TYPES = %w[osor buffer commit demand escalation].freeze

    has_many :osor_lines, dependent: :delete_all, inverse_of: :snapshot
    has_many :escalations, dependent: :delete_all, inverse_of: :snapshot

    enum :status, {
      loading:    "loading",
      active:     "active",
      failed:     "failed",
      superseded: "superseded"
    }

    validates :source_type, inclusion: { in: SOURCE_TYPES }
    validates :region, presence: true

    scope :for_source, ->(source_type, region: DEFAULT_REGION) {
      where(source_type: source_type.to_s, region: region)
    }

    # The snapshot every read should go through.
    def self.current(source_type, region: DEFAULT_REGION)
      for_source(source_type, region: region).active.order(activated_at: :desc).first
    end

    # Activating is the only moment data becomes visible, so it is also the only
    # place the guards can be enforced. Anything that fails here leaves the
    # previous snapshot serving.
    #
    # The supersede is expressed as "every other active snapshot for this
    # source", not "the one I saw before I started". Two ingests overlapping —
    # a scheduled run and a forced one, say — would otherwise both observe the
    # same predecessor and both activate, leaving two live snapshots and making
    # `current` a coin flip.
    def activate!
      transaction do
        self.class.for_source(source_type, region: region)
            .active.where.not(id: id)
            .update_all(status: "superseded", updated_at: Time.current)

        update!(status: :active, activated_at: Time.current)
      end
      self
    end

    def fail!(reason)
      update!(status: :failed, notes: reason)
      self
    end

    def fresh_as_of
      source_modified_at || activated_at
    end
  end
end
