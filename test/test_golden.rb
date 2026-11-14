# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../lib/jalalix"

class TestGolden < Minitest::Test
  GOLDEN = JSON.parse(File.read(File.expand_path("../testdata/golden.json", __dir__)))

  def setup
    assert_equal 1, GOLDEN["version"]
  end

  def create_from(spec)
    if spec.key?("unixMs")
      d = JalaliX.create(spec["unixMs"])
      d = d.setTimezone(spec["timezone"]) if spec["timezone"]
      return d
    end

    JalaliX.create(spec["isoDate"])
  end

  def test_calendar
    GOLDEN["calendar"].each do |c|
      d = create_from(c["create"])
      e = c["expect"]
      assert_equal e["formatYYYYMMDD"], d.format("YYYY/MM/DD"), c["id"]
      assert_equal e["toISODateGregorian"], d.toISODate, c["id"]
      assert_equal e["toISODateJalali"], d.toISODate("jalali"), c["id"]
    end
  end

  def test_parse
    GOLDEN["parse"].each do |c|
      d = JalaliX.parseJalali(c["input"])
      e = c["expect"]
      assert_equal e["toISODateGregorian"], d.toISODate, c["id"]
      assert_equal e["formatYYYYMMDD"], d.format("YYYY/MM/DD"), c["id"] if e["formatYYYYMMDD"]
    end
  end

  def test_format
    GOLDEN["format"].each do |c|
      if c["toPersian"]
        assert_equal c["toPersian"]["expect"], JalaliX.toPersian(c["toPersian"]["input"])
        assert_equal c["fromPersian"]["expect"], JalaliX.fromPersian(c["fromPersian"]["input"])
        next
      end

      d = create_from(c["create"])
      opts = c["options"]
      options = nil

      if opts
        options = {}
        options[:persianDigits] = opts["persianDigits"] if opts.key?("persianDigits")
        options[:calendar] = opts["calendar"] if opts.key?("calendar")
      end

      assert_equal c["expect"], d.format(c["pattern"], options), c["id"]
    end
  end

  def test_timezone
    GOLDEN["timezone"].each do |c|
      if c["setTimezoneAlias"]
        d = JalaliX.create(c["unixMs"]).setTimezone(c["setTimezoneAlias"])
        assert_equal c["expectTimezone"], d.getTimezone, c["id"]
        next
      end

      d = JalaliX.create(c["unixMs"]).setTimezone(c["withTimezone"])
      e = c["expect"]
      assert_equal e["jalaliSlash"], d.format("YYYY/MM/DD"), c["id"]
      assert_equal e["jalaliIso"], d.toISODate("jalali"), c["id"] if e["jalaliIso"]
      assert_equal e["wallGregorian"], d.toISODate, c["id"] if e["wallGregorian"]
      assert_equal e["wallTime"], d.format("HH:mm:ss"), c["id"] if e["wallTime"]
      assert_equal e["hours"], d.getHours, c["id"]
      assert_equal e["minutes"], d.getMinutes, c["id"]
      assert_equal e["getTime"], d.getTime, c["id"] if e.key?("getTime")
    end
  end

  def test_mutations
    GOLDEN["mutations"].each do |c|
      d = create_from(c["create"])

      if c["setFullYear"]
        sfy = c["setFullYear"]
        d.setFullYear(sfy["year"], sfy["month0"], sfy["day"])
        assert_equal c["expect"]["getMonth"], d.getMonth, c["id"]
        assert_equal c["expect"]["formatYYYYMMDD"], d.format("YYYY/MM/DD"), c["id"]
        next
      end

      c["ops"].each do |op|
        if op.start_with?("addMonths:")
          d = d.addMonths(op.split(":", 2)[1].to_i)
        elsif op == "getStartOfMonth"
          d = d.getStartOfMonth
        end
      end

      assert_equal c["expect"]["formatYYYYMMDD"], d.format("YYYY/MM/DD"), c["id"]
    end
  end
end
