# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/jalalix"

class TestNormalizeQueryDate < Minitest::Test
  def test_from_persian_arabic_indic_digits
    assert_equal "۱۴۰۳/۱۲/۰۷", JalaliX.toPersian("1403/12/07")
    assert_equal "1403/12/07", JalaliX.fromPersian("۱۴۰۳/۱۲/۰۷")
    assert_equal "1403/12/07", JalaliX.fromPersian("١٤٠٣/١٢/٠٧")
  end

  def test_parse_jalali_dot_separator
    assert_equal "2025-02-25", JalaliX.parseJalali("1403.12.07").toISODate
  end

  def test_normalize_query_date_sentinels_and_timestamps
    assert_nil JalaliX.normalizeQueryDate(nil)
    assert_nil JalaliX.normalizeQueryDate("null")
    assert_nil JalaliX.normalizeQueryDate("")
    assert_nil JalaliX.normalizeQueryDate("undefined")
    assert_nil JalaliX.normalizeQueryDate("Invalid Date")
    assert_nil JalaliX.normalizeQueryDate("NaN")
    assert_nil JalaliX.normalizeQueryDate(0)
    assert_nil JalaliX.normalizeQueryDate(-1)

    seconds = 1_740_430_800
    assert_equal "2025-02-24 21:00:00", JalaliX.normalizeQueryDate(seconds, timezone: "UTC")
    assert_equal "2025-02-25 00:30:00", JalaliX.normalizeQueryDate(seconds * 1000, timezone: "Asia/Tehran")
  end

  def test_normalize_query_date_jalali_and_gregorian
    assert_equal "2025-02-25 00:00:00", JalaliX.normalizeQueryDate("1403/12/07", timezone: "UTC")
    assert_equal "2025-02-25 14:30:00", JalaliX.normalizeQueryDate("۱۴۰۳-۱۲-۰۷ 14:30:00", timezone: "UTC")
    assert_equal "2025-02-25 00:00:00", JalaliX.normalizeQueryDate("2025.02.25")
    assert_equal "2025-02-25 12:30:45", JalaliX.normalizeQueryDate("2025-02-25 12:30:45.123Z")
    assert_equal "not-a-date", JalaliX.normalizeQueryDate("not-a-date")

    assert JalaliX.normalizeQueryDate("1200/01/01", timezone: "UTC")
    assert JalaliX.normalizeQueryDate("1800/01/01", timezone: "UTC")

    assert_equal "2025-01-01 00:00:00", JalaliX.normalizeQueryDate("2025-01-01")

    widened = { timezone: "UTC", jalaliYearMin: 1, jalaliYearMax: 3000 }
    refute_equal "2025-01-01 00:00:00", JalaliX.normalizeQueryDate("2025-01-01", widened)
  end
end