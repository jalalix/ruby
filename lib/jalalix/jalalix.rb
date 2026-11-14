# frozen_string_literal: true

require "time"
require "date"

# JalaliX — Jalali (Persian / Shamsi) calendar for Ruby.
# Pure Ruby port of @jalalix/typescript — same algorithm and camelCase API.
# Timezone: system zoneinfo via ENV["TZ"] when available; embedded fixed
# offsets for golden zones (UTC, Asia/Tehran +03:30 since 2022) as fallback.
class JalaliX
  PERSIAN_NUMBERS = %w[۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹].freeze

  # Fixed offsets (seconds east of UTC) for zones needed without zoneinfo.
  # Asia/Tehran abolished DST in 2022 -> permanent +03:30.
  EMBEDDED_OFFSETS = {
    "UTC" => 0,
    "Etc/UTC" => 0,
    "GMT" => 0,
    "Asia/Tehran" => 3 * 3600 + 30 * 60,
    "Asia/Tokyo" => 9 * 3600
  }.freeze

  WallParts = Struct.new(:year, :month, :day, :hour, :minute, :second, :ms, keyword_init: true)

  attr_reader :_ms, :_timezone

  def initialize(ms = nil)
    @_ms = ms.nil? ? (Time.now.to_f * 1000).to_i : ms.to_i
    @_timezone = "UTC"
    @_jalali = {
      year: 1348, month: 10, day: 11,
      hours: 0, min: 0, sec: 0, ms: 0, isLeapYear: false
    }
    @_is_converted = false
    @_leap_year_division = 0.24219858156
    @_first_day_of_week = 6
    @_date_length = 86_400_000
    @_week_days_names = %w[شنبه یکشنبه دوشنبه سه\ شنبه چهار\ شنبه پنج\ شنبه جمعه]
    @_week_days_letters = %w[ش ی د س چ پ ج]
    @_week_days_gregorian_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
    @_week_days_gregorian_letters = %w[S M T W T F S]
    @_months_names = %w[فروردین اردیبهشت خرداد تیر مرداد شهریور مهر آبان آذر دی بهمن اسفند]
    @_months_gregorian_names = %w[January February March April May June July August September October November December]
    @_am = "ق.ظ."
    @_pm = "ب.ظ."
    @_am_gregorian = "AM"
    @_pm_gregorian = "PM"
  end

  def self.host_timezone
    tz = ENV["TZ"]
    return tz if tz && !tz.empty?

    # Try local Time zone name
    begin
      name = Time.now.zone
      return "UTC" if name.nil? || name.empty?
    rescue StandardError
    end
    "UTC"
  end

  def self.zone_known?(name)
    return true if EMBEDDED_OFFSETS.key?(name)
    return true if name == "UTC"
    # Probe system zoneinfo via ENV TZ
    old = ENV["TZ"]
    begin
      ENV["TZ"] = name
      Time.now
      true
    rescue StandardError
      false
    ensure
      if old.nil?
        ENV.delete("TZ")
      else
        ENV["TZ"] = old
      end
    end
  end

  # Offset seconds east of UTC for this instant in the given IANA zone.
  def self.offset_seconds_at(ms, zone)
    return 0 if zone.nil? || zone.empty? || zone.upcase == "UTC" || zone == "Etc/UTC" || zone.upcase == "GMT"

    if EMBEDDED_OFFSETS.key?(zone) && (zone == "Asia/Tehran" || zone.start_with?("Etc/") || zone == "Asia/Tokyo")
      # Prefer system zoneinfo when present; fall back to embedded.
      sys = system_offset_seconds(ms, zone)
      return sys unless sys.nil?
      return EMBEDDED_OFFSETS[zone]
    end

    sys = system_offset_seconds(ms, zone)
    return sys unless sys.nil?

    emb = EMBEDDED_OFFSETS[zone]
    return emb unless emb.nil?

    raise ArgumentError, "Invalid IANA timezone: #{zone}"
  end

  def self.system_offset_seconds(ms, zone)
    old = ENV["TZ"]
    begin
      ENV["TZ"] = zone
      t = Time.at(ms / 1000.0)
      # Time#utc_offset is seconds east of UTC
      t.utc_offset
    rescue StandardError
      nil
    ensure
      if old.nil?
        ENV.delete("TZ")
      else
        ENV["TZ"] = old
      end
    end
  end

  def self.wall_from_ms(ms, zone)
    off = offset_seconds_at(ms, zone)
    # Civil time as if UTC
    wall_ms = ms + off * 1000
    sec = wall_ms.div(1000)
    milli = wall_ms - sec * 1000
    if milli.negative?
      sec -= 1
      milli += 1000
    end
    t = Time.at(sec).utc
    WallParts.new(
      year: t.year, month: t.month, day: t.day,
      hour: t.hour, minute: t.min, second: t.sec,
      ms: milli
    )
  end

  # Map wall clock in zone -> UTC ms (iterative for DST).
  def self.wall_to_utc(zone, y, m, d, h, mi, s, ms)
    want = Time.utc(y, m, d, h, mi, s).to_i * 1000
    utc = want
    14.times do
      parts = wall_from_ms(utc, zone)
      got = Time.utc(parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second).to_i * 1000
      diff = want - got
      break if diff.zero?
      utc += diff
    end
    (utc.div(1000) * 1000) + (((ms % 1000) + 1000) % 1000)
  end

  def get_wall_parts
    self.class.wall_from_ms(@_ms, @_timezone)
  end

  def wall_to_utc(y, m, d, h, mi, s, ms)
    self.class.wall_to_utc(@_timezone, y, m, d, h, mi, s, ms)
  end

  def to_jalali
    unless @_is_converted
      wall = get_wall_parts
      civil_day = Time.utc(wall.year, wall.month, wall.day).to_i / (@_date_length / 1000)
      base_day = Time.utc(1970, 1, 1).to_i / (@_date_length / 1000)
      diff_days = civil_day - base_day

      @_jalali[:year] = 1348
      @_jalali[:month] = 10
      @_jalali[:day] = 11

      if diff_days.positive?
        diff_days.times do
          @_jalali[:day] += 1
          if @_jalali[:month] < 7 && @_jalali[:day] > 31
            @_jalali[:month] += 1
            @_jalali[:day] = 1
          elsif @_jalali[:month] > 6 && @_jalali[:month] < 12 && @_jalali[:day] > 30
            @_jalali[:month] += 1
            @_jalali[:day] = 1
          elsif @_jalali[:month] == 12
            leap = check_leap_year(@_jalali[:year])
            if leap && @_jalali[:day] > 30
              @_jalali[:year] += 1
              @_jalali[:month] = 1
              @_jalali[:day] = 1
            elsif !leap && @_jalali[:day] > 29
              @_jalali[:year] += 1
              @_jalali[:month] = 1
              @_jalali[:day] = 1
            end
          end
        end
      elsif diff_days.negative?
        (-diff_days).times do
          @_jalali[:day] -= 1
          next unless @_jalali[:day] < 1

          if @_jalali[:month] == 1
            @_jalali[:year] -= 1
            @_jalali[:month] = 12
            @_jalali[:day] = check_leap_year(@_jalali[:year]) ? 30 : 29
          elsif @_jalali[:month] < 8
            @_jalali[:month] -= 1
            @_jalali[:day] = 31
          elsif @_jalali[:month] < 13
            @_jalali[:month] -= 1
            @_jalali[:day] = 30
          end
        end
      end

      @_jalali[:hours] = wall.hour
      @_jalali[:min] = wall.minute
      @_jalali[:sec] = wall.second
      @_jalali[:ms] = wall.ms
      @_jalali[:isLeapYear] = check_leap_year(@_jalali[:year])
      @_is_converted = true
    end

    wall = get_wall_parts
    @_jalali[:hours] = wall.hour
    @_jalali[:min] = wall.minute
    @_jalali[:sec] = wall.second
    @_jalali[:ms] = wall.ms
    @_jalali
  end

  def to_gregorian(j_date)
    wall = get_wall_parts
    jalali = {
      year: 1348, month: 10, day: 11,
      hours: j_date[:hours] || j_date["hours"] || wall.hour,
      min: j_date[:min] || j_date["min"] || wall.minute,
      sec: j_date[:sec] || j_date["sec"] || wall.second,
      ms: j_date[:ms] || j_date["ms"] || wall.ms,
      isLeapYear: false
    }
    jy = j_date[:year] || j_date["year"]
    jm = j_date[:month] || j_date["month"]
    jd = j_date[:day] || j_date["day"]
    hours = (j_date.key?(:hours) || j_date.key?("hours")) ? (j_date[:hours] || j_date["hours"]) : wall.hour
    min = (j_date.key?(:min) || j_date.key?("min")) ? (j_date[:min] || j_date["min"]) : wall.minute
    sec = (j_date.key?(:sec) || j_date.key?("sec")) ? (j_date[:sec] || j_date["sec"]) : wall.second
    ms = (j_date.key?(:ms) || j_date.key?("ms")) ? (j_date[:ms] || j_date["ms"]) : wall.ms

    diff_days = 0
    after = jy > 1348 || (jy == 1348 && jm >= 10) || (jy == 1348 && jm == 10 && jd >= 11)
    before = jy < 1348 || (jy == 1348 && jm < 10) || (jy == 1348 && jm == 10 && jd < 11)

    if after
      loop do
        break if jalali[:year] == jy && jalali[:month] == jm && jalali[:day] == jd

        diff_days += 1
        jalali[:day] += 1
        if jalali[:month] < 7 && jalali[:day] > 31
          jalali[:month] += 1
          jalali[:day] = 1
        elsif jalali[:month] > 6 && jalali[:month] < 12 && jalali[:day] > 30
          jalali[:month] += 1
          jalali[:day] = 1
        elsif jalali[:month] == 12
          leap = check_leap_year(jalali[:year])
          if leap && jalali[:day] > 30
            jalali[:year] += 1
            jalali[:month] = 1
            jalali[:day] = 1
          elsif !leap && jalali[:day] > 29
            jalali[:year] += 1
            jalali[:month] = 1
            jalali[:day] = 1
          end
        end
      end
    elsif before
      loop do
        break if jalali[:year] == jy && jalali[:month] == jm && jalali[:day] == jd

        diff_days -= 1
        jalali[:day] -= 1
        next unless jalali[:day] < 1

        if jalali[:month] == 1
          jalali[:year] -= 1
          jalali[:month] = 12
          jalali[:day] = check_leap_year(jalali[:year]) ? 30 : 29
        elsif jalali[:month] < 8
          jalali[:month] -= 1
          jalali[:day] = 31
        elsif jalali[:month] < 13
          jalali[:month] -= 1
          jalali[:day] = 30
        end
      end
    end

    wall_as_utc = diff_days * @_date_length + (hours * 3600 + min * 60 + sec) * 1000 + ms
    civil = Time.at(wall_as_utc / 1000.0).utc
    wall_to_utc(civil.year, civil.month, civil.day, civil.hour, civil.min, civil.sec, civil.usec / 1000)
  end

  def check_leap_year(year)
    return false unless year.positive?

    check_year = (year + 2346) * @_leap_year_division
    check_year - check_year.to_i < @_leap_year_division
  end

  def reset
    @_is_converted = false
    @_jalali[:year] = 1348
    @_jalali[:month] = 10
    @_jalali[:day] = 11
    to_jalali
  end

  def add_zero(number)
    "#{number > -1 && number < 10 ? '0' : ''}#{number}"
  end

  def get_wall_weekday
    wall = get_wall_parts
    Time.utc(wall.year, wall.month, wall.day).wday
  end

  def get_utc_timezone
    wall = get_wall_parts
    as_utc = Time.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).to_i * 1000 + wall.ms
    offset_min = ((as_utc - @_ms) / 60_000.0).round
    sign = offset_min >= 0 ? "+" : "-"
    abs = offset_min.abs
    " GMT#{sign}#{add_zero(abs / 60)}#{add_zero(abs % 60)}"
  end

  def normalize_date(days)
    setTime(@_ms + days * @_date_length)
  end

  def normalize_jalali(j_date, year, month, day)
    if month < 1
      year_diff = ((1 - month) / 12.0).ceil
      year -= year_diff
      month = 12 * year_diff + month
    elsif month > 12
      year_diff = ((month - 1) / 12.0).floor
      year += year_diff
      month -= 12 * year_diff
    end

    if month > 6 && month < 12 && day > 30
      day = 30
    elsif month == 12
      leap = check_leap_year(year)
      if leap && day > 30
        day = 30
      elsif !leap && day > 29
        day = 29
      end
    end

    merged = j_date.merge(year: year, month: month, day: day)
    setTime(to_gregorian(merged))
  end

  def normalize_timezone(timezone)
    return @_timezone if timezone.nil?

    trimmed = timezone.to_s.strip
    raise ArgumentError, "Invalid IANA timezone: empty" if trimmed.empty?

    lowered = trimmed.downcase
    return self.class.host_timezone if %w[default local system].include?(lowered)
    return "UTC" if %w[utc gmt].include?(lowered)

    # Validate
    begin
      self.class.offset_seconds_at(@_ms, trimmed)
    rescue ArgumentError
      raise ArgumentError, "Invalid IANA timezone: #{trimmed}"
    end
    trimmed
  end

  def toString
    j = to_jalali
    "#{week_day_name} #{add_zero(j[:day])} #{@_months_names[j[:month] - 1]} #{add_zero(j[:year])} #{j[:hours]}:#{add_zero(j[:min])}:#{add_zero(j[:sec])}#{get_utc_timezone}"
  end
  alias to_s toString

  def toDateString
    j = to_jalali
    "#{week_day_name} #{add_zero(j[:day])} #{@_months_names[j[:month] - 1]} #{add_zero(j[:year])}"
  end

  def toLocaleDateString
    j = to_jalali
    "#{add_zero(j[:year])}/#{add_zero(j[:month])}/#{add_zero(j[:day])}"
  end

  def toLocaleTimeString
    j = to_jalali
    "#{j[:hours] % 12}:#{add_zero(j[:min])}:#{add_zero(j[:sec])} #{getMeridiem}"
  end

  def getFullYear
    to_jalali[:year]
  end

  def getMonth
    to_jalali[:month]
  end

  def getDate
    to_jalali[:day]
  end

  def getDay
    (get_wall_weekday - @_first_day_of_week + 7 + 1) % 7
  end

  def getHours
    get_wall_parts.hour
  end

  def getMinutes
    get_wall_parts.minute
  end

  def getSeconds
    get_wall_parts.second
  end

  def getMilliseconds
    ((@_ms % 1000) + 1000) % 1000
  end

  def getTime
    @_ms
  end

  def setTime(time)
    @_ms = time.to_i
    reset
    getTime
  end

  def setMilliseconds(ms)
    wall = get_wall_parts
    setTime(wall_to_utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second, ms))
  end

  def setSeconds(sec, ms = nil)
    wall = get_wall_parts
    setTime(wall_to_utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, sec, ms.nil? ? wall.ms : ms))
  end

  def setMinutes(min, sec = nil, ms = nil)
    wall = get_wall_parts
    setTime(wall_to_utc(wall.year, wall.month, wall.day, wall.hour, min, sec.nil? ? wall.second : sec, ms.nil? ? wall.ms : ms))
  end

  def setHours(hours, min = nil, sec = nil, ms = nil)
    wall = get_wall_parts
    setTime(wall_to_utc(wall.year, wall.month, wall.day, hours, min.nil? ? wall.minute : min, sec.nil? ? wall.second : sec, ms.nil? ? wall.ms : ms))
  end

  def setDate(date)
    j = to_jalali
    normalize_date(date - j[:day])
    getTime
  end

  def setMonth(month, date = nil)
    j = to_jalali
    normalize_jalali(j, j[:year], month + 1, j[:day])
    reset
    unless date.nil?
      j = to_jalali
      normalize_date(date - j[:day])
      reset
    end
    getTime
  end

  def setFullYear(year, month = nil, date = nil)
    j = to_jalali
    normalize_jalali(j, year, month.nil? ? j[:month] : month + 1, j[:day])
    reset
    unless date.nil?
      j = to_jalali
      normalize_date(date - j[:day])
      reset
    end
    getTime
  end

  def self.create(date, options = nil)
    ms = parse_input(date)
    output = new(ms)
    if options.is_a?(Hash) && (options[:timezone] || options["timezone"])
      output = output.setTimezone(options[:timezone] || options["timezone"])
    end
    output
  end

  def self.parse_input(value)
    case value
    when JalaliX then value.getTime
    when Integer, Float then value.to_i
    when Time then (value.to_f * 1000).to_i
    when Date then Time.utc(value.year, value.month, value.day).to_i * 1000
    when String then parse_iso_string(value)
    else
      raise TypeError, "JalaliX.create: unsupported date type #{value.class}"
    end
  end

  def self.parse_iso_string(value)
    s = value.strip
    if s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      y, m, d = s.split("-").map(&:to_i)
      return Time.utc(y, m, d).to_i * 1000
    end
    t = Time.parse(s)
    (t.to_f * 1000).to_i
  rescue StandardError
    raise ArgumentError, "JalaliX.create: invalid date string #{value.inspect}"
  end

  def self.parseJalali(value, options = nil)
    normalized = fromPersian(value.to_s).strip
    match = normalized.match(/\A(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?\z/)
    raise ArgumentError, "JalaliX.parseJalali: invalid Jalali date \"#{value}\"" unless match

    year = match[1].to_i
    month = match[2].to_i
    day = match[3].to_i
    hours = (match[4] || 0).to_i
    minutes = (match[5] || 0).to_i
    seconds = (match[6] || 0).to_i
    raise ArgumentError, "JalaliX.parseJalali: invalid Jalali date \"#{value}\"" if month < 1 || month > 12 || day < 1 || day > 31

    output = create(Time.now, options)
    output.setFullYear(year, month - 1, day)
    output.setHours(hours, minutes, seconds, 0)
    output
  end

  def self.isValidDate(date)
    date.is_a?(JalaliX) || date.is_a?(Time) || date.is_a?(Date)
  end

  def self.toPersian(str)
    out = str.dup
    10.times { |i| out = out.gsub(i.to_s, PERSIAN_NUMBERS[i]) }
    out
  end

  def self.fromPersian(str)
    out = str.dup
    10.times { |i| out = out.gsub(PERSIAN_NUMBERS[i], i.to_s) }
    out
  end

  def self.compare(date, comparing)
    date.getTime < comparing.getTime
  end

  def clone
    output = JalaliX.new(@_ms)
    output.instance_variable_set(:@_timezone, @_timezone)
    output
  end

  def getTimezone
    @_timezone
  end

  def getWeekOfYear
    day_of_year = getDayOfYear
    day_of_week = JalaliX.new(@_ms).tap { |d| d.instance_variable_set(:@_timezone, @_timezone) }.getStartOfYear.getDayISO
    ((day_of_year + day_of_week - 1) / 7.0).ceil
  end

  def getDayOfYear
    j = to_jalali
    if j[:month] < 7
      j[:day] + (j[:month] - 1) * 31
    elsif j[:month] < 12
      j[:day] + 186 + (j[:month] - 7) * 30
    else
      j[:day] + 336
    end
  end

  def getDayISO
    ((getDay + 6) % 7) + 1
  end

  def getHoursISO
    hours = getHours
    hours > 12 ? hours - 12 : hours
  end

  def getMeridiem
    j = to_jalali
    j[:hours] > 12 ? @_pm : @_am
  end

  def getStartOfYear
    addDays(-1 * getDayOfYear + 1).getStartOfDay
  end

  def getStartOfMonth
    addDays(-1 * getDate + 1).getStartOfDay
  end

  def getStartOfWeek
    addDays(-1 * getDayISO + 1).getStartOfDay
  end

  def getStartOfDay
    setHours(0, 0, 0, 0)
    self
  end

  def getEndOfYear
    j = to_jalali
    last = j[:isLeapYear] ? 366 : 365
    addDays(last - getDayOfYear).getEndOfDay
  end

  def getEndOfMonth
    j = to_jalali
    last = 31
    if j[:month] > 6 && j[:month] < 12
      last = 30
    elsif j[:month] == 12
      last = j[:isLeapYear] ? 30 : 29
    end
    addDays(last - getDate).getEndOfDay
  end

  def getEndOfWeek
    addDays(7 - getDayISO).getEndOfDay
  end

  def getEndOfDay
    setHours(23, 59, 59, 999)
    self
  end

  def setTimezone(timezone)
    output = JalaliX.new(@_ms)
    output.instance_variable_set(:@_timezone, normalize_timezone(timezone))
    output
  end

  def addYears(year)
    j = to_jalali
    normalize_jalali(j, j[:year] + year, j[:month], j[:day])
    reset
    self
  end

  def addMonths(month)
    j = to_jalali
    normalize_jalali(j, j[:year], j[:month] + month, j[:day])
    reset
    self
  end

  def addWeeks(weeks)
    normalize_date(weeks * 7)
    reset
    self
  end

  def addDays(days)
    normalize_date(days)
    reset
    self
  end

  def toISODate(calendar = "gregorian")
    return format("YYYY-MM-DD") if calendar.to_s == "jalali"

    wall = get_wall_parts
    "#{wall.year}-#{add_zero(wall.month)}-#{add_zero(wall.day)}"
  end

  def format(str, persian_or_options = nil, gregorian = nil)
    persian = false
    use_gregorian = false
    if persian_or_options.is_a?(Hash)
      persian = !!(persian_or_options[:persianDigits] || persian_or_options["persianDigits"])
      cal = persian_or_options[:calendar] || persian_or_options["calendar"]
      use_gregorian = cal.to_s == "gregorian"
    else
      persian = !!persian_or_options
      use_gregorian = !!gregorian
    end

    placeholders = []
    ph = lambda do |val|
      i = placeholders.length
      placeholders << val
      "\uE000#{i}\uE001"
    end

    output = str.dup
    wall = get_wall_parts
    year = use_gregorian ? wall.year : getFullYear
    month = use_gregorian ? wall.month : getMonth
    week_of_year = use_gregorian ? gregorian_week_of_year : getWeekOfYear
    day_of_year = use_gregorian ? gregorian_day_of_year : getDayOfYear
    date = use_gregorian ? wall.day : getDate
    month_name = use_gregorian ? @_months_gregorian_names[month - 1] : @_months_names[month - 1]
    week_day_name_val = use_gregorian ? @_week_days_gregorian_names[get_wall_weekday] : week_day_name
    week_day_letter = use_gregorian ? @_week_days_gregorian_letters[get_wall_weekday] : @_week_days_letters[(getDay + @_first_day_of_week) % 7]
    meridiem = use_gregorian ? (getHours >= 12 ? @_pm_gregorian : @_am_gregorian) : getMeridiem
    year_str = year.to_s

    {
      "YYYY" => year_str,
      "YYY" => year_str[-3..],
      "YY" => year_str[-2..],
      "Y" => year_str[-1],
      "MMM" => month_name,
      "MM" => add_zero(month),
      "M" => month.to_s,
      "W" => add_zero(week_of_year),
      "w" => week_of_year.to_s,
      "DW" => getDayISO.to_s,
      "dw" => (use_gregorian ? (get_wall_weekday.zero? ? 7 : get_wall_weekday) : getDay).to_s,
      "WN" => week_day_name_val,
      "wn" => week_day_name_val,
      "WL" => week_day_letter,
      "wl" => week_day_letter,
      "DDDD" => add_zero(day_of_year),
      "DDD" => day_of_year.to_s,
      "DD" => add_zero(date),
      "D" => date.to_s
    }.each do |token, val|
      output.gsub!(token, ph.call(val)) if output.include?(token)
    end

    hours = getHours
    output.gsub!("HH", ph.call(add_zero(hours))) if output.include?("HH")
    output.gsub!("H", ph.call(hours.to_s)) if output.include?("H")
    hours_iso = hours > 12 ? hours - 12 : (hours.zero? ? 12 : hours)
    output.gsub!("hh", ph.call(add_zero(hours_iso))) if output.include?("hh")
    output.gsub!("h", ph.call(hours_iso.to_s)) if output.include?("h")
    output.gsub!("mm", ph.call(add_zero(getMinutes))) if output.include?("mm")
    output.gsub!("m", ph.call(getMinutes.to_s)) if output.include?("m")
    output.gsub!("ss", ph.call(add_zero(getSeconds))) if output.include?("ss")
    output.gsub!("s", ph.call(getSeconds.to_s)) if output.include?("s")
    output.gsub!("sss", ph.call(getMilliseconds.to_s)) if output.include?("sss")
    output.gsub!("SSS", ph.call(getMilliseconds.to_s)) if output.include?("SSS")
    output.gsub!("A", ph.call(meridiem)) if output.include?("A")
    output.gsub!("a", ph.call(meridiem)) if output.include?("a")
    output.gsub!("X", ph.call((@_ms / 1000).floor.to_s)) if output.include?("X")
    output.gsub!("x", ph.call(@_ms.to_s)) if output.include?("x")

    placeholders.each_with_index do |val, i|
      output.gsub!("\uE000#{i}\uE001", val)
    end

    persian ? self.class.toPersian(output) : output
  end

  private

  def week_day_name
    @_week_days_names[(getDay + @_first_day_of_week) % 7]
  end

  def gregorian_day_of_year
    wall = get_wall_parts
    start = Time.utc(wall.year, 1, 1) - 86_400
    civil = Time.utc(wall.year, wall.month, wall.day)
    ((civil - start) / 86_400).round
  end

  def gregorian_week_of_year
    wall = get_wall_parts
    d = Time.utc(wall.year, wall.month, wall.day)
    dow = d.wday
    dow = 7 if dow.zero?
    d += (4 - dow) * 86_400
    year_start = Time.utc(d.year, 1, 1)
    ((((d - year_start) / 86_400) + 1) / 7.0).ceil
  end
end
