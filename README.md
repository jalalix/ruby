# JalaliX - Ruby

Jalali (Persian / Shamsi) calendar for Ruby. Pure Ruby 3.0+, no runtime gems (timezone via stdlib `ENV["TZ"]` / zoneinfo, with embedded offsets for golden parity).

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

```bash
gem install jalalix
# or: bundle add jalalix
```

```ruby
require "jalalix"

date = JalaliX.create("2025-02-25")

date.format("YYYY/MM/DD")  # 1403/12/07
date.format("DD MMM YYYY", persianDigits: true)  # ۰۷ اسفند ۱۴۰۳

JalaliX.parseJalali("1403/12/07").toISODate  # 2025-02-25
```

`toISODate` uses wall-clock getters in the active timezone.

## Install

```bash
gem install jalalix
# or: bundle add jalalix
```

```ruby
require "jalalix"
```

## Usage

### create / format

```ruby
now = JalaliX.create(Time.now.to_f * 1000, timezone: "Asia/Tehran")

now.format("YYYY/MM/DD")
now.format("WN، DD MMM YYYY")
now.format("YYYY/MM/DD", persianDigits: true)
now.format("DD MMM YYYY", calendar: "gregorian")
```

`format` accepts a hash with `:persianDigits` / `:calendar`, or positional `persian_or_options` and `gregorian` flags.

### parseJalali

```ruby
JalaliX.parseJalali("1403/12/07")
JalaliX.parseJalali("۱۴۰۳-۱۲-۰۷ 14:30")
JalaliX.parseJalali("1403.12.07")
```

Named `parseJalali` because Ruby's `Date` / `Time` already have parsers. Accepts `/`, `-`, or `.` as the date separator.

### normalizeQueryDate

Soft-normalize loose API/query date values to a Gregorian `YYYY-MM-DD HH:mm:ss` string (or `nil`). Does not raise on junk input.

```ruby
JalaliX.normalizeQueryDate("1403/12/07", timezone: "Asia/Tehran")
# => "2025-02-25 00:00:00"

JalaliX.normalizeQueryDate("undefined")  # nil
JalaliX.normalizeQueryDate(1_740_430_800_000, timezone: "Asia/Tehran")
# => "2025-02-25 00:30:00"
```

Handles sentinels, unix timestamps (seconds or milliseconds; non-positive → `nil`), Persian/Arabic-Indic digits, `/` `-` `.` separators, fractional seconds, optional `Z` / offset suffixes.

Detects Jalali when the year is in `jalaliYearMin`…`jalaliYearMax` (default `1`…`1899`) **and** the civil date is valid; otherwise Gregorian when valid, or returns the digit-cleaned string. Non-string/non-number values pass through unchanged.

### toISODate

```ruby
d = JalaliX.create("2025-02-25T00:30:00+03:30")

d.toISODate           # "2025-02-25"
d.toISODate("jalali") # "1403-12-07"
```

### add / start / end

```ruby
JalaliX.create("2025-02-25").addMonths(1).getStartOfMonth.format("YYYY/MM/DD")
# e.g. 1404/01/01

d = JalaliX.create("2025-02-25", timezone: "Asia/Tehran")
d.addDays(7).format("YYYY/MM/DD")
d.getEndOfWeek.format("YYYY/MM/DD")
```

### Persian / Arabic digits

```ruby
JalaliX.toPersian("1403/12/07")   # ۱۴۰۳/۱۲/۰۷
JalaliX.fromPersian("۱۴۰۳/۱۲/۰۷") # 1403/12/07
JalaliX.fromPersian("١٤٠٣/١٢/٠٧") # 1403/12/07 (Arabic-Indic)
```

## Timezone

Internal storage is always a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**: the timestamp stays the same; only the zone (and therefore wall clock / Jalali day) changes.

```ruby
d = JalaliX.create(1_740_430_800_000)

tehran = d.setTimezone("Asia/Tehran")
tehran.format("YYYY/MM/DD")  # 1403/12/07
tehran.format("HH:mm")       # 00:30

utc = d.setTimezone("UTC")
utc.format("YYYY/MM/DD")     # 1403/12/06
utc.format("HH:mm")          # 21:00

tehran.getTime == utc.getTime # true
```

- **Aliases:** `utc` / `gmt` → `UTC`; `local` / `default` / `system` → host zone when detectable.
- **Invalid zone** → `ArgumentError`.
- Offsets use system zoneinfo through `ENV["TZ"]` when available; `Asia/Tehran` (+03:30 since 2022) and `UTC` are also embedded so golden parity works without TZInfo.

```ruby
JalaliX.create(Time.now.to_f * 1000, timezone: "Asia/Tehran")
```

## Months

Easy to get wrong:

- `getMonth()` → **1…12** (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` → **0…11**, same as JavaScript `Date` (Farvardin = 0)

```ruby
d = JalaliX.create
d.setFullYear(1404, 0, 1) # 1 Farvardin 1404
d.getMonth # 1
```

## Format tokens

| Token               | Meaning                         |
| ------------------- | ------------------------------- |
| `YYYY` `YY`         | year                            |
| `MMM` `MM` `M`      | month name / number             |
| `DD` `D`            | day                             |
| `HH` `hh` `mm` `ss` | time                            |
| `A` `a`             | meridiem (ق.ظ. / ب.ظ. or AM/PM) |
| `WN` `WL`           | weekday name / letter           |
| `w` `DDD`           | week of year / day of year      |
| `X` `x`             | unix seconds / ms               |

## API

Options hashes use `:timezone`, `:jalaliYearMin`, `:jalaliYearMax` (for `normalizeQueryDate`), `:persianDigits`, and `:calendar` (for `format`).

### Constants

| API               | Description                                     |
| ----------------- | ----------------------------------------------- |
| `PERSIAN_NUMBERS` | Array of Persian digit characters `۰`…`۹`.      |
| `ARABIC_NUMBERS`  | Array of Arabic-Indic digit characters `٠`…`٩`. |

### Class methods

| API                                          | Description                                                                                                 |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `JalaliX.create(date, options)`              | Build from unix ms, ISO string, `Time`, `Date`, or `JalaliX`; optional `timezone` in options hash.          |
| `JalaliX.parseJalali(value, options)`        | Parse a Jalali date/time string (`/` `-` `.`, Persian/Arabic digits, optional time).                        |
| `JalaliX.normalizeQueryDate(value, options)` | Soft-normalize loose query values → Gregorian `YYYY-MM-DD HH:mm:ss`, cleaned string, passthrough, or `nil`. |
| `JalaliX.isValidDate(date)`                  | `true` if the value is a supported date type.                                                               |
| `JalaliX.toPersian(str)`                     | Replace Western digits `0-9` with Persian `۰-۹`.                                                            |
| `JalaliX.fromPersian(str)`                   | Replace Persian `۰-۹` and Arabic-Indic `٠-٩` with Western digits.                                           |
| `JalaliX.compare(date, comparing)`           | `true` if the first date is strictly before the second (by unix ms).                                        |
| `JalaliX.host_timezone`                      | Resolve host timezone name for `local` / `default` / `system` aliases.                                      |

### Instance - getters

| API               | Description                                                           |
| ----------------- | --------------------------------------------------------------------- |
| `getFullYear`     | Jalali year in the active timezone.                                   |
| `getMonth`        | Jalali month **1…12** (Farvardin = 1).                                |
| `getDate`         | Jalali day of month **1…31**.                                         |
| `getDay`          | Weekday **1…7** (Saturday = 1 … Friday = 7).                          |
| `getHours`        | Wall-clock hours in the active timezone.                              |
| `getMinutes`      | Wall-clock minutes.                                                   |
| `getSeconds`      | Wall-clock seconds.                                                   |
| `getMilliseconds` | Wall-clock milliseconds.                                              |
| `getTime`         | Unix timestamp in milliseconds (UTC instant).                         |
| `getTimezone`     | Active IANA timezone id.                                              |
| `getWeekOfYear`   | Jalali week-of-year (1-based).                                        |
| `getDayOfYear`    | Day of Jalali year (1…365/366).                                       |
| `getDayISO`       | ISO-style weekday index used internally for week math.                |
| `getHoursISO`     | Hours in 0…23 for formatting helpers.                                 |
| `getMeridiem`     | Localized meridiem string (ق.ظ./ب.ظ. or AM/PM depending on calendar). |

### Instance - setters

| API                              | Description                                              |
| -------------------------------- | -------------------------------------------------------- |
| `setTime(time)`                  | Set the UTC instant from unix milliseconds.              |
| `setMilliseconds(ms)`            | Set milliseconds (wall clock).                           |
| `setSeconds(sec, ms)`            | Set seconds and optional milliseconds.                   |
| `setMinutes(min, sec, ms)`       | Set minutes and optional lower units.                    |
| `setHours(hours, min, sec, ms)`  | Set hours and optional lower units.                      |
| `setDate(date)`                  | Set Jalali day of month.                                 |
| `setMonth(month, date)`          | Set Jalali month **0…11** (Farvardin = 0); optional day. |
| `setFullYear(year, month, date)` | Set Jalali year; optional month **0…11** and day.        |
| `setTimezone(timezone)`          | Instant-preserving zone change; returns a new instance.  |

### Instance - math, range, format

| API                                          | Description                                            |
| -------------------------------------------- | ------------------------------------------------------ |
| `addYears(year)`                             | Add calendar years (mutates / returns `self`).         |
| `addMonths(month)`                           | Add calendar months.                                   |
| `addWeeks(weeks)`                            | Add weeks.                                             |
| `addDays(days)`                              | Add days.                                              |
| `getStartOfYear`                             | Start of Jalali year (mutates / returns `self`).       |
| `getStartOfMonth`                            | Start of Jalali month.                                 |
| `getStartOfWeek`                             | Start of week.                                         |
| `getStartOfDay`                              | Start of day (`00:00:00.000`).                         |
| `getEndOfYear`                               | End of Jalali year.                                    |
| `getEndOfMonth`                              | End of Jalali month.                                   |
| `getEndOfWeek`                               | End of week.                                           |
| `getEndOfDay`                                | End of day (`23:59:59.999`).                           |
| `format(str, persian_or_options, gregorian)` | Format with tokens; hash options or positional flags.  |
| `toISODate(calendar)`                        | `YYYY-MM-DD` in `"gregorian"` (default) or `"jalali"`. |
| `clone`                                      | Copy with the same instant and timezone.               |
| `toString`                                   | Human-readable Jalali date/time string.                |
| `toDateString`                               | Jalali weekday + date string.                          |
| `toLocaleDateString`                         | `YYYY/MM/DD` in Jalali.                                |
| `toLocaleTimeString`                         | 12-hour time with meridiem.                            |

## Test

```bash
rake test
# or: ruby -Ilib:test test/test_golden.rb
```

## Links

- https://jalalix.com
- https://github.com/jalalix/ruby
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
