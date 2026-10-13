require "test_helper"

class YearRangeTest < ActiveSupport::TestCase
  UNPARSABLE = "Escribe un año (2024) o un periodo (2023–2024)"

  test "parses a single year" do
    assert_equal [ 2024, nil ], YearRange.parse("2024")
    assert_equal [ 2024, nil ], YearRange.parse("  2024 ")
  end

  test "parses ranges written with a hyphen, an en dash or an em dash, with or without spaces" do
    [ "2023-2024", "2023–2024", "2023—2024", "2023 — 2024", "2023 - 2024", "2023 –2024" ].each do |text|
      assert_equal [ 2023, 2024 ], YearRange.parse(text), text
    end
  end

  test "parses dashes and spaces pasted from a word processor" do
    assert_equal [ 2023, 2024 ], YearRange.parse("2023−2024")                         # minus sign
    assert_equal [ 2023, 2024 ], YearRange.parse("2023‑2024")                         # non-breaking hyphen
    assert_equal [ 2023, 2024 ], YearRange.parse(" 2023 – 2024 ") # no-break spaces
  end

  test "parses the short form, where 2023-24 means 2024" do
    assert_equal [ 2023, 2024 ], YearRange.parse("2023-24")
    assert_equal [ 2023, 2024 ], YearRange.parse("2023–24")
    assert_equal [ 1999, 2001 ], YearRange.parse("1999-01")
  end

  test "parses blank text as no year" do
    assert_equal [ nil, nil ], YearRange.parse("")
    assert_equal [ nil, nil ], YearRange.parse("   ")
    assert_equal [ nil, nil ], YearRange.parse(nil)
  end

  test "rejects anything else" do
    [ "hacia 2020", "2024a", "20", "202", "20245", "2023/2024", "2023-2", "2023-2024-2025", "año 2024", "2023 y 2024" ].each do |text|
      assert_nil YearRange.parse(text), text
    end
  end

  test "the years field fills both columns" do
    artwork = artworks(:bare)

    artwork.years = "2023-24"
    assert_equal [ 2023, 2024 ], [ artwork.year, artwork.year_end ]
    assert artwork.valid?

    artwork.years = "2021"
    assert_equal [ 2021, nil ], [ artwork.year, artwork.year_end ]

    artwork.years = ""
    assert_equal [ nil, nil ], [ artwork.year, artwork.year_end ]
    assert artwork.valid?
  end

  test "unparsable text is a Spanish error on the years field, as a whole sentence" do
    artwork = artworks(:collage)
    artwork.years = "hacia 2020"

    assert_not artwork.valid?
    assert_equal [ UNPARSABLE ], artwork.errors[:years]
    assert_includes artwork.errors.full_messages, UNPARSABLE
    assert_equal [ 2024, nil ], [ artwork.year, artwork.year_end ], "the stored years are left alone"
    assert_equal "hacia 2020", artwork.years, "the form shows what was typed"
  end

  test "the same rules apply to torn posters" do
    poster = torn_posters(:street)
    poster.years = "dos mil"

    assert_not poster.valid?
    assert_equal [ UNPARSABLE ], poster.errors[:years]
    assert_includes poster.errors.full_messages, UNPARSABLE
  end

  test "the end year must come after the first" do
    artwork = artworks(:collage)

    [ "2024-2023", "2024-2024" ].each do |text|
      artwork.years = text
      assert_not artwork.valid?, text
      assert_equal [ "El año final debe ser posterior al inicial" ], artwork.errors[:years]
    end
  end

  test "an end year needs a first year" do
    artwork = artworks(:collage)
    artwork.year = nil
    artwork.year_end = 2024

    assert_not artwork.valid?
    assert_equal [ "Falta el año inicial del periodo" ], artwork.errors[:years]
  end

  test "years run from 1900 to next year" do
    artwork = artworks(:collage)
    last_year = Date.current.year + 1
    message = "Los años deben estar entre 1900 y #{last_year}"

    artwork.years = "1900"
    assert artwork.valid?
    artwork.years = last_year.to_s
    assert artwork.valid?

    artwork.years = "1899"
    assert_not artwork.valid?
    assert_equal [ message ], artwork.errors[:years]

    artwork.years = "2020-#{last_year + 1}"
    assert_not artwork.valid?
    assert_equal [ message ], artwork.errors[:years]
  end

  test "years_label uses an en dash with no spaces, and is nil without a year" do
    assert_equal "2024", artworks(:collage).years_label
    assert_equal "2022–2023", artworks(:range).years_label
    assert_nil artworks(:bare).years_label
    assert_equal "2019–2020", torn_posters(:wall).years_label
  end

  test "the years field shows the stored years, and the normalised years after saving" do
    artwork = artworks(:range)
    assert_equal "2022–2023", artwork.years

    artwork.update!(years: "2020 - 21")
    assert_equal "2020–2021", artwork.years
    assert_equal "2020–2021", artwork.reload.years
  end

  test "sort_year is the last year" do
    assert_equal 2023, artworks(:range).sort_year
    assert_equal 2024, artworks(:collage).sort_year
    assert_nil artworks(:bare).sort_year
  end
end
