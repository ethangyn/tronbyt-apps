"""
Applet: Visual Countdown
Summary: Themed visual countdown
Description: Count down to any event with original pixel-art themes for birthdays, travel, holidays, and more.
Author: ethangyn
"""

load("render.star", "canvas", "render")
load("schema.star", "schema")
load("time.star", "time")

DEFAULT_EVENT = "MY EVENT"

MODE_DAYS = "days"
MODE_WEEKS = "weeks"
MODE_MONTHS = "months"
MODE_YEARS = "years"
MODE_AUTO = "auto"
MODE_MONTHS_DAYS = "months_days"
MODE_YMD = "ymd"

THEME_CELEBRATION = "celebration"
THEME_BIRTHDAY = "birthday"
THEME_TRAVEL = "travel"
THEME_SUMMER = "summer"
THEME_HOLIDAY = "holiday"
THEME_LAUNCH = "launch"
THEME_WEDDING = "wedding"

VALID_MODES = {
    MODE_DAYS: True,
    MODE_WEEKS: True,
    MODE_MONTHS: True,
    MODE_YEARS: True,
    MODE_AUTO: True,
    MODE_MONTHS_DAYS: True,
    MODE_YMD: True,
}

# Theme palettes control background, number, unit, and event-name colors.
THEMES = {
    THEME_CELEBRATION: {
        "bg": "#140f24",
        "number": "#ffd166",
        "unit": "#c9b8ff",
        "event": "#f4f0ff",
        "muted": "#8c82a8",
    },
    THEME_BIRTHDAY: {
        "bg": "#1c1028",
        "number": "#ff8ec9",
        "unit": "#ffd6a5",
        "event": "#fff4e6",
        "muted": "#9a7a96",
    },
    THEME_TRAVEL: {
        "bg": "#071828",
        "number": "#7ec8ff",
        "unit": "#b8e0d2",
        "event": "#eef6ff",
        "muted": "#6d8799",
    },
    THEME_SUMMER: {
        "bg": "#072033",
        "number": "#ffd23f",
        "unit": "#7ad7f0",
        "event": "#fff6d8",
        "muted": "#6e8ea3",
    },
    THEME_HOLIDAY: {
        "bg": "#08140e",
        "number": "#e8f4ea",
        "unit": "#f2c14e",
        "event": "#ffd7d7",
        "muted": "#6f8a74",
    },
    THEME_LAUNCH: {
        "bg": "#070714",
        "number": "#f4f1ff",
        "unit": "#ff9f4a",
        "event": "#d7e3ff",
        "muted": "#6d7090",
    },
    THEME_WEDDING: {
        "bg": "#1a1018",
        "number": "#f0c36a",
        "unit": "#f3b3c4",
        "event": "#fff4ea",
        "muted": "#8a7380",
    },
}

# -------------------------
# Date helpers
# -------------------------

def is_leap(year):
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

def days_in_month(year, month):
    if month == 2:
        return 29 if is_leap(year) else 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31

def valid_ymd(year, month, day):
    if year < 1 or year > 9999 or month < 1 or month > 12 or day < 1:
        return False
    return day <= days_in_month(year, month)

def julian_day(year, month, day):
    # Gregorian civil calendar to Julian Day Number.
    a = (14 - month) // 12
    y = year + 4800 - a
    m = month + 12 * a - 3
    return day + (153 * m + 2) // 5 + 365 * y + y // 4 - y // 100 + y // 400 - 32045

def add_months(year, month, day, count):
    total = (year * 12 + (month - 1)) + count
    next_year = total // 12
    next_month = total % 12 + 1
    next_day = min(day, days_in_month(next_year, next_month))
    return (next_year, next_month, next_day)

def ymd_tuple(t):
    return (t.year, t.month, t.day)

def ymd_less(a, b):
    return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]) or (a[0] == b[0] and a[1] == b[1] and a[2] < b[2])

def calendar_span(start, end):
    end_ymd = ymd_tuple(end)
    total_days = julian_day(end.year, end.month, end.day) - julian_day(start.year, start.month, start.day)
    if total_days < 0:
        total_days = 0

    months = (end.year - start.year) * 12 + (end.month - start.month)
    if months < 0:
        months = 0
    probe = add_months(start.year, start.month, start.day, months)
    if months > 0 and ymd_less(end_ymd, probe):
        months -= 1

    anchor = add_months(start.year, start.month, start.day, months)
    leftover_days = julian_day(end.year, end.month, end.day) - julian_day(anchor[0], anchor[1], anchor[2])
    years = months // 12
    leftover_months = months % 12
    weeks = total_days // 7
    leftover_week_days = total_days % 7

    return {
        "years": years,
        "months": leftover_months,
        "total_months": months,
        "days": leftover_days,
        "total_days": total_days,
        "weeks": weeks,
        "week_days": leftover_week_days,
        "end": end_ymd,
    }

def plural(count, singular, plural_word):
    return singular if count == 1 else plural_word

# -------------------------
# Config
# -------------------------

FALLBACK_TZ = "America/New_York"
EVENT_NAME_MAX = 32

def valid_timezone_name(zone):
    if zone == None or type(zone) != "string" or zone == "":
        return False
    if zone == "UTC" or zone == "GMT":
        return True
    if "/" not in zone:
        return False
    for i in range(len(zone)):
        c = zone[i]
        letter = (c >= "A" and c <= "Z") or (c >= "a" and c <= "z")
        digit = c >= "0" and c <= "9"
        extra = c == "/" or c == "_" or c == "-" or c == "+"
        if not (letter or digit or extra):
            return False
    parts = zone.split("/")
    if len(parts) < 2 or len(parts) > 3:
        return False
    for part in parts:
        if part == "":
            return False
    return True

def fallback_timezone():
    zone = time.tz()
    if valid_timezone_name(zone):
        return zone
    return FALLBACK_TZ

def json_string_field(raw, field):
    needle = "\"" + field + "\""
    start = raw.find(needle)
    if start < 0:
        return None
    i = start + len(needle)
    for _ in range(8):
        if i >= len(raw):
            return None
        c = raw[i]
        if c == " " or c == "\t" or c == "\n" or c == "\r" or c == ":":
            i += 1
        else:
            break
    if i >= len(raw) or raw[i] != "\"":
        return None
    i += 1
    begin = i
    escaped = False
    for _ in range(len(raw) - i):
        if i >= len(raw):
            return None
        c = raw[i]
        if escaped:
            escaped = False
            i += 1
            continue
        if c == "\\":
            escaped = True
            i += 1
            continue
        if c == "\"":
            return raw[begin:i]
        i += 1
    return None

def timezone_from_config(config):
    raw = config.get("location")
    if type(raw) == "dict":
        zone = raw.get("timezone")
        if valid_timezone_name(zone):
            return zone
        return fallback_timezone()
    if type(raw) != "string" or raw.strip() == "":
        return fallback_timezone()
    zone = json_string_field(raw, "timezone")
    if valid_timezone_name(zone):
        return zone
    return fallback_timezone()

def default_target(now, timezone):
    later = add_months(now.year, now.month, now.day, 1)
    return time.time(year = later[0], month = later[1], day = later[2], hour = 0, minute = 0, second = 0, location = timezone)

def digits_only(value):
    if value == None or value == "":
        return False
    for i in range(len(value)):
        if value[i] < "0" or value[i] > "9":
            return False
    return True

def parse_ymd(raw):
    if raw == None or type(raw) != "string" or len(raw) < 10 or raw[4] != "-" or raw[7] != "-":
        return None
    year_s = raw[0:4]
    month_s = raw[5:7]
    day_s = raw[8:10]
    if not digits_only(year_s) or not digits_only(month_s) or not digits_only(day_s):
        return None
    year = int(year_s)
    month = int(month_s)
    day = int(day_s)
    if not valid_ymd(year, month, day):
        return None
    return (year, month, day)

def parse_clock(rest):
    if rest == None or len(rest) < 5 or rest[2] != ":":
        return None
    hour_s = rest[0:2]
    minute_s = rest[3:5]
    if not digits_only(hour_s) or not digits_only(minute_s):
        return None
    hour = int(hour_s)
    minute = int(minute_s)
    if hour > 23 or minute > 59:
        return None
    second = 0
    idx = 5
    if len(rest) >= 8 and rest[5] == ":":
        second_s = rest[6:8]
        if not digits_only(second_s):
            return None
        second = int(second_s)
        if second > 59:
            return None
        idx = 8
        if len(rest) > idx and rest[idx] == ".":
            idx += 1
            started = idx
            for _ in range(len(rest) - idx):
                if idx >= len(rest) or rest[idx] < "0" or rest[idx] > "9":
                    break
                idx += 1
            if idx == started:
                return None
    tz_mode = "local"
    if idx < len(rest):
        tail = rest[idx:]
        if tail.startswith("Z") or tail.startswith("z"):
            tz_mode = "utc"
        elif len(tail) >= 6 and (tail[0] == "+" or tail[0] == "-") and tail[3] == ":" and digits_only(tail[1:3]) and digits_only(tail[4:6]):
            tz_mode = "offset"
        elif tail.strip() != "":
            return None
    return (hour, minute, second, tz_mode, rest)

def offset_seconds(rest):
    tail_start = 5
    if len(rest) >= 8 and rest[5] == ":":
        tail_start = 8
        if len(rest) > tail_start and rest[tail_start] == ".":
            tail_start += 1
            for _ in range(len(rest) - tail_start):
                if tail_start >= len(rest) or rest[tail_start] < "0" or rest[tail_start] > "9":
                    break
                tail_start += 1
    if tail_start >= len(rest):
        return 0
    tail = rest[tail_start:]
    if tail.startswith("Z") or tail.startswith("z"):
        return 0
    if len(tail) < 6:
        return 0
    sign = -1 if tail[0] == "-" else 1
    hours = int(tail[1:3])
    minutes = int(tail[4:6])
    return sign * (hours * 3600 + minutes * 60)

def parse_event_time(raw, timezone, now, use_time):
    if raw == None or type(raw) != "string" or raw.strip() == "":
        return default_target(now, timezone)

    raw = raw.strip()
    parsed = parse_ymd(raw)
    if parsed == None:
        return default_target(now, timezone)

    year, month, day = parsed
    if not use_time or len(raw) == 10:
        return time.time(year = year, month = month, day = day, hour = 0, minute = 0, second = 0, location = timezone)

    if raw[10] != "T" and raw[10] != "t" and raw[10] != " ":
        return time.time(year = year, month = month, day = day, hour = 0, minute = 0, second = 0, location = timezone)

    clock = parse_clock(raw[11:])
    if clock == None:
        return time.time(year = year, month = month, day = day, hour = 0, minute = 0, second = 0, location = timezone)

    hour, minute, second, tz_mode, rest = clock
    if tz_mode == "utc":
        utc = time.time(year = year, month = month, day = day, hour = hour, minute = minute, second = second, location = "UTC")
        return utc.in_location(timezone)
    if tz_mode == "offset":
        utc = time.time(year = year, month = month, day = day, hour = hour, minute = minute, second = second, location = "UTC")
        off = offset_seconds(rest)
        if off >= 0:
            utc = utc - time.parse_duration("%ds" % off)
        else:
            utc = utc + time.parse_duration("%ds" % (-off))
        return utc.in_location(timezone)
    return time.time(year = year, month = month, day = day, hour = hour, minute = minute, second = second, location = timezone)

def theme_id(config):
    value = config.get("theme", THEME_CELEBRATION)
    if value in THEMES:
        return value
    return THEME_CELEBRATION

def mode_id(config):
    value = config.get("mode", MODE_AUTO)
    if value in VALID_MODES:
        return value
    return MODE_AUTO

def hex_digit(ch):
    return (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F")

def custom_hex(config, key):
    value = config.get(key)
    if value == None or type(value) != "string" or value == "" or value[0] != "#":
        return None
    body = value[1:]
    if len(body) != 3 and len(body) != 4 and len(body) != 6 and len(body) != 8:
        return None
    for i in range(len(body)):
        if not hex_digit(body[i]):
            return None
    if len(body) == 4 and body[3] == "0":
        return None
    if len(body) == 8 and body[6:8] == "00":
        return None
    return value

def clip_text(value, max_len):
    if value == None:
        return ""
    if len(value) <= max_len:
        return value
    return value[0:max_len]

# -------------------------
# Countdown formatting
# -------------------------

def remaining_clock(now, target):
    hours = int((target - now).hours)
    if hours < 0:
        hours = 0
    minutes = int((target - now).minutes) % 60
    if hours > 0:
        return {"status": "future", "primary": str(hours), "unit": plural(hours, "HOUR", "HOURS").upper(), "secondary": ""}
    return {"status": "future", "primary": str(minutes), "unit": plural(minutes, "MIN", "MINS").upper(), "secondary": ""}

def countdown_view(now, target, use_time, mode):
    if use_time:
        remaining = target.unix - now.unix
        if remaining < 0:
            span = calendar_span(target, now)
            return format_units(span, mode, "past")
        if remaining < 60:
            return {"status": "now", "primary": "NOW", "unit": "", "secondary": ""}
        span = calendar_span(now, target)
        if span["total_days"] == 0:
            return remaining_clock(now, target)
        return format_units(span, mode, "future")

    now_date = (now.year, now.month, now.day)
    target_date = (target.year, target.month, target.day)
    if now_date == target_date:
        return {"status": "today", "primary": "TODAY", "unit": "", "secondary": ""}
    if ymd_less(target_date, now_date):
        span = calendar_span(target, now)
        return format_units(span, mode, "past")
    span = calendar_span(now, target)
    return format_units(span, mode, "future")

def format_units(span, mode, status):
    years = span["years"]
    months = span["months"]
    days = span["days"]
    total_days = span["total_days"]
    weeks = span["weeks"]
    week_days = span["week_days"]
    total_months = span["total_months"]

    chosen = mode
    if mode == MODE_AUTO:
        if years >= 2:
            chosen = MODE_YEARS
        elif years == 1 or total_months >= 2:
            chosen = MODE_MONTHS_DAYS
        elif total_days >= 14:
            chosen = MODE_WEEKS
        else:
            chosen = MODE_DAYS

    if chosen == MODE_DAYS:
        return pack(str(total_days), plural(total_days, "DAY", "DAYS"), "", status)
    if chosen == MODE_WEEKS:
        if weeks == 0:
            return pack(str(total_days), plural(total_days, "DAY", "DAYS"), "", status)
        secondary = "%d %s" % (week_days, plural(week_days, "DAY", "DAYS")) if week_days > 0 else ""
        return pack(str(weeks), plural(weeks, "WEEK", "WEEKS"), secondary, status)
    if chosen == MODE_MONTHS:
        if total_months == 0:
            return pack(str(total_days), plural(total_days, "DAY", "DAYS"), "", status)
        secondary = "%d %s" % (days, plural(days, "DAY", "DAYS")) if days > 0 else ""
        return pack(str(total_months), plural(total_months, "MONTH", "MONTHS"), secondary, status)
    if chosen == MODE_YEARS:
        if years == 0:
            if total_months == 0:
                return pack(str(total_days), plural(total_days, "DAY", "DAYS"), "", status)
            secondary = "%d %s" % (days, plural(days, "DAY", "DAYS")) if days > 0 else ""
            return pack(str(total_months), plural(total_months, "MONTH", "MONTHS"), secondary, status)
        secondary = "%d %s" % (months, plural(months, "MONTH", "MONTHS")) if months > 0 else ""
        return pack(str(years), plural(years, "YEAR", "YEARS"), secondary, status)
    if chosen == MODE_MONTHS_DAYS:
        secondary = "%d %s" % (days, plural(days, "DAY", "DAYS")) if days > 0 or total_months == 0 else ""
        primary = str(total_months)
        unit = plural(total_months, "MONTH", "MONTHS")
        if total_months == 0:
            return pack(str(days), plural(days, "DAY", "DAYS"), "", status)
        return pack(primary, unit, secondary, status)

    # years + months + days
    if years == 0 and total_months == 0:
        return pack(str(total_days), plural(total_days, "DAY", "DAYS"), "", status)
    if years == 0:
        secondary = "%d %s" % (days, plural(days, "DAY", "DAYS")) if days > 0 else ""
        return pack(str(total_months), plural(total_months, "MONTH", "MONTHS"), secondary, status)
    extra = []
    if months > 0:
        extra.append("%d %s" % (months, plural(months, "MO", "MO")))
    if days > 0:
        extra.append("%d %s" % (days, plural(days, "DAY", "DAYS")))
    return pack(str(years), plural(years, "YEAR", "YEARS"), " ".join(extra), status)

def pack(primary, unit, secondary, status):
    suffix = ""
    if status == "past":
        suffix = "AGO"
    return {
        "status": status,
        "primary": primary,
        "unit": unit.upper(),
        "secondary": (secondary.upper() + (" " + suffix if suffix and secondary else suffix)).strip(),
    }

# -------------------------
# Pixel scenes
# Each item is (x, y, w, h, color) on a 24x32 canvas.
# -------------------------

def px(x, y, w, h, color, scale):
    return render.Padding(
        pad = (x * scale, y * scale, 0, 0),
        child = render.Box(width = w * scale, height = h * scale, color = color),
    )

def circle(x, y, diameter, color, scale):
    return render.Padding(
        pad = (x * scale, y * scale, 0, 0),
        child = render.Circle(diameter = diameter * scale, color = color),
    )

def paint(items, scale):
    return [px(item[0], item[1], item[2], item[3], item[4], scale) for item in items]

def scene_box(bg, children, scale):
    return render.Stack(
        children = [render.Box(width = 24 * scale, height = 32 * scale, color = bg)] + children,
    )

def scene_celebration(scale, frame):
    confetti_a = [
        (2, 3, 1, 1, "#ffd166"),
        (8, 2, 1, 1, "#9b5de5"),
        (14, 4, 1, 1, "#00bbf9"),
        (19, 3, 1, 1, "#f15bb5"),
        (5, 7, 1, 1, "#00f5d4"),
        (21, 8, 1, 1, "#ffd166"),
    ]
    confetti_b = [
        (3, 4, 1, 1, "#9b5de5"),
        (9, 3, 1, 1, "#00bbf9"),
        (13, 5, 1, 1, "#ffd166"),
        (18, 2, 1, 1, "#00f5d4"),
        (6, 8, 1, 1, "#f15bb5"),
        (20, 7, 1, 1, "#9b5de5"),
    ]
    burst = [
        (11, 11, 2, 8, "#ffd166"),
        (8, 14, 8, 2, "#ffd166"),
        (9, 12, 6, 1, "#ffe08a"),
        (9, 17, 6, 1, "#ffe08a"),
        (7, 13, 1, 4, "#9b5de5"),
        (16, 13, 1, 4, "#9b5de5"),
        (10, 20, 4, 2, "#00bbf9"),
        (6, 22, 12, 2, "#3d2b66"),
        (8, 24, 8, 3, "#2a1d4d"),
        (4, 27, 16, 2, "#21163d"),
    ]
    extras = confetti_a if frame == 0 else confetti_b
    return scene_box("#140f24", paint(burst + extras, scale), scale)

def scene_birthday(scale, frame):
    flame = "#ffb703" if frame == 0 else "#ffd166"
    flame_h = 2 if frame == 0 else 1
    items = [
        (3, 2, 5, 6, "#ff6b9d"),
        (15, 1, 5, 6, "#ffd166"),
        (5, 8, 1, 4, "#e8d5c4"),
        (17, 7, 1, 4, "#e8d5c4"),
        (7, 14, 1, 4, "#fff4c2"),
        (11, 13, 1, 5, "#fff4c2"),
        (15, 14, 1, 4, "#fff4c2"),
        (7, 14 - flame_h, 1, flame_h, flame),
        (11, 13 - flame_h, 1, flame_h, flame),
        (15, 14 - flame_h, 1, flame_h, flame),
        (4, 18, 16, 3, "#ffe8ef"),
        (5, 21, 14, 5, "#ff8ec9"),
        (4, 26, 16, 3, "#f4d6a5"),
        (3, 29, 18, 2, "#d9b384"),
        (1, 4, 1, 1, "#ffd6e8"),
        (21, 3, 1, 1, "#fff0b3"),
    ]
    return scene_box("#1c1028", paint(items, scale) + [
        circle(3, 1, 6, "#ff6b9d", scale),
        circle(14, 0, 6, "#ffd166", scale),
    ], scale)

def scene_travel(scale, frame):
    plane_x = 2 + frame
    items = [
        (0, 18, 24, 6, "#13344f"),
        (2, 16, 7, 5, "#2f6b4f"),
        (7, 13, 9, 7, "#245742"),
        (14, 15, 8, 6, "#2c7a57"),
        (0, 23, 24, 4, "#0f2a40"),
        (0, 27, 24, 5, "#3d2a1c"),
        (19, 2, 3, 2, "#d9ecff"),
        (18, 3, 1, 1, "#d9ecff"),
        (plane_x, 7, 11, 3, "#e8f1f8"),
        (plane_x + 11, 8, 3, 2, "#c5d5e4"),
        (plane_x + 4, 5, 5, 2, "#c5d5e4"),
        (plane_x + 4, 10, 5, 2, "#9bb4c8"),
        (plane_x, 6, 2, 2, "#7ec8ff"),
        (plane_x + 6, 8, 2, 1, "#7ec8ff"),
        (2, 26, 6, 4, "#8b5a2b"),
        (3, 25, 4, 1, "#c48a4a"),
        (7, 27, 1, 2, "#6a4220"),
    ]
    return scene_box("#071828", paint(items, scale), scale)

def scene_summer(scale, frame):
    wave = 23 + frame
    items = [
        (16, 2, 6, 6, "#ffd23f"),
        (15, 1, 1, 1, "#ffe58a"),
        (22, 1, 1, 1, "#ffe58a"),
        (14, 5, 1, 1, "#ffe58a"),
        (23, 5, 1, 1, "#ffe58a"),
        (0, wave, 24, 4, "#1c7ea8"),
        (0, wave + 3, 24, 9, "#125e86"),
        (0, 29, 24, 3, "#e0c07a"),
        (3, 12, 2, 12, "#8a5a2b"),
        (2, 8, 8, 5, "#2f9e5a"),
        (1, 11, 5, 3, "#247a44"),
        (7, 10, 4, 3, "#36b068"),
        (10 + frame, 27, 3, 2, "#f4e3b2"),
    ]
    return scene_box("#072033", paint(items, scale) + [circle(16, 2, 6, "#ffd23f", scale)], scale)

def scene_holiday(scale, frame):
    twinkle = "#fff7c2" if frame == 0 else "#7ad7f0"
    items = [
        (11, 1, 2, 2, "#f2c14e"),
        (8, 4, 8, 3, "#1f7a3a"),
        (6, 7, 12, 4, "#186533"),
        (4, 11, 16, 5, "#14552b"),
        (3, 16, 18, 5, "#0f4422"),
        (10, 21, 4, 3, "#6b3e1f"),
        (2, 26, 6, 4, "#c43b3b"),
        (16, 25, 6, 5, "#d4a017"),
        (3, 25, 4, 1, "#f2d6d6"),
        (17, 24, 4, 1, "#ffe08a"),
        (7, 8, 1, 1, "#c43b3b"),
        (15, 9, 1, 1, "#f2c14e"),
        (9, 13, 1, 1, twinkle),
        (14, 15, 1, 1, "#c43b3b"),
        (6, 17, 1, 1, "#f2c14e"),
        (1, 3 + frame, 1, 1, "#e8f4ea"),
        (20, 5 - frame, 1, 1, "#e8f4ea"),
        (12, 28, 1, 1, "#e8f4ea"),
    ]
    return scene_box("#08140e", paint(items, scale), scale)

def scene_launch(scale, frame):
    flame = "#ff9f4a" if frame == 0 else "#ffd166"
    flame_h = 4 if frame == 0 else 3
    items = [
        (3, 2, 1, 1, "#f4f1ff"),
        (18, 4, 1, 1, "#9bb0ff"),
        (8, 5, 1, 1, "#f4f1ff"),
        (21, 9, 1, 1, "#ffd166"),
        (2, 12, 1, 1, "#9bb0ff"),
        (11, 3, 2, 3, "#f4f1ff"),
        (10, 6, 4, 10, "#d7e3ff"),
        (11, 8, 2, 4, "#7ec8ff"),
        (9, 16, 6, 3, "#b8c4dc"),
        (8, 18, 2, 3, "#ff6b4a"),
        (14, 18, 2, 3, "#ff6b4a"),
        (11, 19, 2, flame_h, flame),
        (10, 20, 4, 1, "#ff4d2e"),
        (0, 28, 24, 4, "#1b1b33"),
        (6, 26, 12, 2, "#3a3a5c"),
        (20, 14 + frame, 1, 1, "#f4f1ff"),
    ]
    return scene_box("#070714", paint(items, scale), scale)

def scene_wedding(scale, frame):
    heart = "#f3b3c4" if frame == 0 else "#ffd6e0"
    items = [
        (3, 22, 4, 3, "#d77a94"),
        (4, 21, 2, 1, "#d77a94"),
        (16, 21, 4, 3, heart),
        (17, 20, 2, 1, heart),
        (11, 24, 3, 3, "#f0c36a"),
        (10, 26, 5, 2, "#c9a24b"),
        (2, 4, 1, 1, "#fff4ea"),
        (21, 6, 1, 1, "#f0c36a"),
        (8, 3, 1, 1, heart),
    ]
    return scene_box("#1a1018", paint(items, scale) + [
        circle(4, 8, 8, "#f0c36a", scale),
        circle(6, 10, 4, "#1a1018", scale),
        circle(10, 10, 8, "#e8d5a3", scale),
        circle(12, 12, 4, "#1a1018", scale),
    ], scale)

def render_scene(theme, scale, frame):
    if theme == THEME_BIRTHDAY:
        return scene_birthday(scale, frame)
    if theme == THEME_TRAVEL:
        return scene_travel(scale, frame)
    if theme == THEME_SUMMER:
        return scene_summer(scale, frame)
    if theme == THEME_HOLIDAY:
        return scene_holiday(scale, frame)
    if theme == THEME_LAUNCH:
        return scene_launch(scale, frame)
    if theme == THEME_WEDDING:
        return scene_wedding(scale, frame)
    return scene_celebration(scale, frame)

# -------------------------
# Layout
# -------------------------

def number_font(text, scale):
    length = len(text)
    if scale == 2:
        if length <= 4:
            return "terminus-18"
        return "terminus-14"
    if length <= 4:
        return "6x13"
    return "5x8"

def unit_font(scale):
    return "tb-8" if scale == 2 else "CG-pixel-3x5-mono"

def event_font(scale):
    return "tb-8" if scale == 2 else "tom-thumb"

def centered_text(content, width, font, color):
    child = render.Text(content = content, font = font, color = color)
    return render.Box(
        width = width,
        child = render.Row(expanded = True, main_align = "center", children = [child]),
    )

def named_marquee(content, width, font, color):
    return render.Marquee(
        width = width,
        align = "center",
        child = render.Text(content = content, font = font, color = color),
    )

def build_text_column(view, event_name, colors, scale, width):
    status = view["status"]
    number_color = colors["number"]
    unit_color = colors["unit"]
    event_color = colors["event"]
    if status == "past":
        unit_color = colors["muted"]
        number_color = colors["muted"]

    inner = width - 2 * scale
    if inner < 16:
        inner = width

    children = []
    if view["unit"]:
        children.append(
            render.Row(
                expanded = True,
                main_align = "center",
                cross_align = "end",
                children = [
                    render.Text(content = view["primary"], font = number_font(view["primary"], scale), color = number_color),
                    render.Box(width = 2 * scale, height = 1),
                    render.Text(content = view["unit"], font = unit_font(scale), color = unit_color),
                ],
            ),
        )
    else:
        children.append(centered_text(view["primary"], inner, number_font(view["primary"], scale), number_color))

    if view["secondary"]:
        children.append(centered_text(view["secondary"], inner, unit_font(scale), colors["muted"]))
    if scale == 2 and status == "future" and event_name:
        children.append(centered_text("UNTIL", inner, "tom-thumb", colors["muted"]))
    if event_name:
        children.append(named_marquee(event_name, inner, event_font(scale), event_color))

    return render.Box(
        width = width,
        height = canvas.height(),
        child = render.Padding(
            pad = (1 * scale, 1 * scale, 1 * scale, 1 * scale),
            child = render.Column(
                expanded = True,
                main_align = "center",
                cross_align = "center",
                children = children,
            ),
        ),
    )

def build_layout(view, event_name, theme, colors, scale):
    scene_w = 24 * scale
    text_w = canvas.width() - scene_w
    return render.Stack(
        children = [
            render.Box(width = canvas.width(), height = canvas.height(), color = colors["bg"]),
            render.Row(
                expanded = True,
                main_align = "start",
                cross_align = "center",
                children = [
                    build_text_column(view, event_name, colors, scale, text_w),
                    render.Animation(
                        children = [
                            render_scene(theme, scale, 0),
                            render_scene(theme, scale, 1),
                        ],
                    ),
                ],
            ),
        ],
    )

# -------------------------
# App
# -------------------------

def main(config):
    scale = 2 if canvas.is2x() else 1
    timezone = timezone_from_config(config)
    now = time.now().in_location(timezone)
    use_time = config.bool("use_time", False)
    target = parse_event_time(config.get("event_time"), timezone, now, use_time)
    theme = theme_id(config)
    mode = mode_id(config)
    event_name = config.str("event_name", DEFAULT_EVENT)
    if event_name == None:
        event_name = DEFAULT_EVENT
    event_name = clip_text(event_name.strip(), EVENT_NAME_MAX)
    if event_name == "":
        event_name = DEFAULT_EVENT

    palette = THEMES[theme]
    colors = {
        "bg": palette["bg"],
        "number": palette["number"],
        "unit": palette["unit"],
        "event": palette["event"],
        "muted": palette["muted"],
    }
    number_override = custom_hex(config, "number_color") if config.bool("custom_colors", False) else None
    event_override = custom_hex(config, "event_color") if config.bool("custom_colors", False) else None
    if number_override:
        colors["number"] = number_override
    if event_override:
        colors["event"] = event_override

    view = countdown_view(now, target, use_time, mode)
    delay = 250 if scale == 2 else 450
    long_name = len(event_name) > 10

    return render.Root(
        delay = delay,
        max_age = 1800,
        show_full_animation = long_name,
        child = build_layout(view, event_name, theme, colors, scale),
    )

def color_fields(enabled):
    if enabled == True or enabled == "true" or enabled == "True":
        return [
            schema.Color(
                id = "number_color",
                name = "Number color",
                desc = "Color of the countdown value.",
                icon = "brush",
                default = "#FFFFFF",
                palette = ["#FFFFFF", "#FFD166", "#FF8EC9", "#7EC8FF", "#F0C36A", "#E8F4EA"],
            ),
            schema.Color(
                id = "event_color",
                name = "Event name color",
                desc = "Color of the event name.",
                icon = "brush",
                default = "#F4F0FF",
                palette = ["#F4F0FF", "#FFF4E6", "#EEF6FF", "#FFF6D8", "#FFD7D7"],
            ),
        ]
    return []

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "event_name",
                name = "Event name",
                desc = "Name of the event you are counting down to.",
                icon = "font",
                default = DEFAULT_EVENT,
            ),
            schema.DateTime(
                id = "event_time",
                name = "Event date",
                desc = "Target date, and optional time, of the event.",
                icon = "calendar",
            ),
            schema.Toggle(
                id = "use_time",
                name = "Count to the exact time",
                desc = "When off, the countdown uses the calendar date only.",
                icon = "clock",
                default = False,
            ),
            schema.Dropdown(
                id = "mode",
                name = "Countdown mode",
                desc = "How remaining time is displayed.",
                icon = "sliders",
                default = MODE_AUTO,
                options = [
                    schema.Option(display = "Automatic", value = MODE_AUTO),
                    schema.Option(display = "Days", value = MODE_DAYS),
                    schema.Option(display = "Weeks", value = MODE_WEEKS),
                    schema.Option(display = "Months", value = MODE_MONTHS),
                    schema.Option(display = "Years", value = MODE_YEARS),
                    schema.Option(display = "Months + days", value = MODE_MONTHS_DAYS),
                    schema.Option(display = "Years + months + days", value = MODE_YMD),
                ],
            ),
            schema.Dropdown(
                id = "theme",
                name = "Visual theme",
                desc = "Pixel-art scene and color palette.",
                icon = "palette",
                default = THEME_CELEBRATION,
                options = [
                    schema.Option(display = "Celebration", value = THEME_CELEBRATION),
                    schema.Option(display = "Birthday", value = THEME_BIRTHDAY),
                    schema.Option(display = "Travel", value = THEME_TRAVEL),
                    schema.Option(display = "Summer", value = THEME_SUMMER),
                    schema.Option(display = "Holiday", value = THEME_HOLIDAY),
                    schema.Option(display = "Launch", value = THEME_LAUNCH),
                    schema.Option(display = "Wedding", value = THEME_WEDDING),
                ],
            ),
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Your timezone, so the countdown matches your local date and time.",
                icon = "locationDot",
            ),
            schema.Toggle(
                id = "custom_colors",
                name = "Custom colors",
                desc = "Override the theme colors for the number and event name.",
                icon = "brush",
                default = False,
            ),
            schema.Generated(
                id = "generated_colors",
                source = "custom_colors",
                handler = color_fields,
            ),
        ],
    )
