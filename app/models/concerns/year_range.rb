# A year or a range of years, stored as two integer columns:
# `year` is the first or only year, and `year_end` is set only for a range.
#
# The admin edits one text field, the virtual attribute `years` ("Año"). It accepts
# "2024", "2023-2024", "2023–2024", "2023 — 2024" and the short form "2023-24" (2024).
# Blank clears both columns. The public site shows `years_label`: "2024" or "2023–2024".
#
# Every year error is added to `years`, the field the admin sees.
module YearRange
  extend ActiveSupport::Concern

  FIRST_YEAR = 1900

  # Hyphen-minus, hyphen, non-breaking hyphen, figure dash, en dash, em dash, horizontal bar and minus sign,
  # so text pasted from a word processor works too.
  DASHES = "-‐‑‒–—―−"
  SINGLE_YEAR = /\A(\d{4})\z/
  RANGE = /\A(\d{4})[[:space:]]*[#{DASHES}][[:space:]]*(\d{4}|\d{2})\z/

  # The dash in labels: an en dash with no spaces.
  LABEL_DASH = "–"

  class << self
    # Parses the admin's text into [year, year_end], or returns nil when it isn't a year or a range.
    # The values are not range-checked here; validation does that.
    #
    #   YearRange.parse("2024")       # => [2024, nil]
    #   YearRange.parse("2023–2024")  # => [2023, 2024]
    #   YearRange.parse("2023-24")    # => [2023, 2024]
    #   YearRange.parse("")           # => [nil, nil]
    #   YearRange.parse("hacia 2020") # => nil
    def parse(text)
      text = text.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
      return [ nil, nil ] if text.empty?

      if (match = SINGLE_YEAR.match(text))
        [ match[1].to_i, nil ]
      elsif (match = RANGE.match(text))
        first = match[1].to_i
        [ first, expand_end(first, match[2]) ]
      end
    end

    # The last year a work can carry: next year, so a piece finished at New Year's Eve fits.
    def last_year
      Date.current.year + 1
    end

    # COALESCE(table.year_end, table.year): the year a record sorts by, as an Arel node (reversible in orders).
    def sort_year_node(table)
      Arel::Nodes::NamedFunction.new("COALESCE", [ table[:year_end], table[:year] ])
    end

    private
      # "2023-24" means 2024. A two-digit end year continues the first year's century,
      # or the next century when it would come before it ("1999-01" is 2001).
      def expand_end(first, digits)
        return digits.to_i if digits.length == 4

        candidate = first - (first % 100) + digits.to_i
        candidate <= first ? candidate + 100 : candidate
      end
  end

  included do
    validate :validate_years
    after_save :forget_years_input
  end

  # The text shown in the admin's "Año" field: what the admin typed, or the stored years.
  def years
    defined?(@years_input) ? @years_input : years_label
  end

  def years=(text)
    @years_input = text.to_s
    parsed = YearRange.parse(@years_input)

    if parsed
      @years_unparsable = false
      self.year, self.year_end = parsed
    else
      @years_unparsable = true
    end
  end

  # "2024", "2023–2024" (en dash, no spaces), or nil when there is no year.
  def years_label
    return if year.blank?

    year_end.present? ? "#{year}#{LABEL_DASH}#{year_end}" : year.to_s
  end

  # The year used for sorting: the last year of a range.
  def sort_year
    year_end || year
  end

  def reload(*)
    forget_years_input
    super
  end

  private
    def validate_years
      if @years_unparsable
        errors.add(:years, :years_unparsable)
        return
      end

      allowed = FIRST_YEAR..YearRange.last_year
      if [ year, year_end ].compact.any? { |value| !allowed.cover?(value) }
        errors.add(:years, :years_out_of_range, first: FIRST_YEAR, last: YearRange.last_year)
      end

      if year_end.present? && year.blank?
        errors.add(:years, :year_end_without_year)
      elsif year_end.present? && year_end <= year
        errors.add(:years, :year_end_not_after_year)
      end
    end

    def forget_years_input
      remove_instance_variable(:@years_input) if defined?(@years_input)
      @years_unparsable = false
    end
end
