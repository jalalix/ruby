# JalaliX

Jalali (Persian / Shamsi) calendar for Ruby. Pure Ruby 3.0+, no runtime gems (timezone via stdlib `ENV["TZ"]` / zoneinfo, with embedded offsets for `UTC` and `Asia/Tehran`).

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

`toISODate` uses wall-calendar getters in the active timezone.

## Months

- `getMonth()` -> 1..12 (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` -> 0..11, same as JS `Date` (Farvardin = 0)

## Timezone

Internal storage is a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**.

```ruby
d = JalaliX.create(1_740_430_800_000)
tehran = d.setTimezone("Asia/Tehran")
tehran.format("YYYY/MM/DD")  # 1403/12/07
tehran.format("HH:mm:ss")    # 00:30:00
```

- **Aliases:** `utc` / `gmt` -> `UTC`; `local` / `default` / `system` -> host zone when detectable.
- **Invalid zone** -> `ArgumentError`.
- Offsets use system zoneinfo through `ENV["TZ"]` when available; `Asia/Tehran` (+03:30 since 2022) and `UTC` are also embedded so golden parity works without TZInfo.

## Test

```bash
rake test
# or: ruby -Ilib:test test/test_golden.rb
```

## License

MIT
