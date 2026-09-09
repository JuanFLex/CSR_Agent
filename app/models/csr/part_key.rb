module Csr
  # Key = TRIM(CLEAN(CPN)) & "|" & TRIM(CLEAN(MPN)) — build book Vol.2 §5.
  #
  # This is the single most consequential decision in the model. A CPN can carry
  # more than one MPN (second source), and aggregating those together silently
  # produces wrong numbers, which is why nothing in this app matches on CPN alone.
  #
  # The key answers "which part is this", and nothing else. Plant, ship-to,
  # customer and supplier answer "which situation for that part" — they are
  # context, and they live on the facts. Folding context into the key would also
  # fold in the master-data noise: the FPN splits in the export are the same
  # part written two ways (FCS-<CPN> and FCS-<MPN>), so keying on FPN would
  # invent parts that do not exist.
  class PartKey < ApplicationRecord
    SEPARATOR = "|".freeze

    has_many :osor_lines, dependent: :nullify, inverse_of: :part_key

    validates :key_value, presence: true, uniqueness: { scope: :region }
    validates :cpn, :mpn, presence: true

    scope :by_cpn, ->(cpn) { where(cpn: normalize(cpn)) }
    scope :by_mpn, ->(mpn) { where(mpn: normalize(mpn)) }

    # Excel's TRIM(CLEAN(x)): strip control characters, collapse whitespace.
    # Applied identically to every source, because the Baan and Kinaxis exports
    # disagree about spacing often enough to break joins otherwise.
    def self.normalize(value)
      return nil if value.nil?

      value.to_s.gsub(/[[:cntrl:]]/, "").strip.squeeze(" ").presence
    end

    def self.build_key(cpn, mpn)
      cpn = normalize(cpn)
      mpn = normalize(mpn)
      return nil if cpn.blank? || mpn.blank?

      "#{cpn}#{SEPARATOR}#{mpn}"
    end

    def cpn_part = key_value.to_s.split(SEPARATOR, 2).first
    def mpn_part = key_value.to_s.split(SEPARATOR, 2).last
  end
end
