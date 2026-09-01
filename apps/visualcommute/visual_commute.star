"""
Applet: Visual Commute
Summary: Themed travel time
Description: Show how long it takes to get from one place to another, with original pixel-art scenes for driving, walking, biking, and transit.
Author: ethangyn
"""

load("encoding/json.star", "json")
load("http.star", "http")
load("render.star", "canvas", "render")
load("schema.star", "schema")

DEFAULT_FROM = "HOME"
DEFAULT_TO = "WORK"
LABEL_MAX = 12
ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
CACHE_SECONDS = 300

MODE_DRIVE = "drive"
MODE_WALK = "walk"
MODE_BIKE = "bike"
MODE_TRANSIT = "transit"
THEME_AUTO = "auto"

VALID_MODES = {
    MODE_DRIVE: True,
    MODE_WALK: True,
    MODE_BIKE: True,
    MODE_TRANSIT: True,
}

GOOGLE_MODES = {
    MODE_DRIVE: "DRIVE",
    MODE_WALK: "WALK",
    MODE_BIKE: "BICYCLE",
    MODE_TRANSIT: "TRANSIT",
}

THEMES = {
    MODE_DRIVE: {
        "bg": "#000000",
        "number": "#7ec8ff",
        "unit": "#f2c14e",
        "event": "#e8eef6",
        "muted": "#7a8796",
        "delay": "#ff9f4a",
    },
    MODE_WALK: {
        "bg": "#000000",
        "number": "#b8e0d2",
        "unit": "#ffd166",
        "event": "#fff4ea",
        "muted": "#7a8796",
        "delay": "#ff9f4a",
    },
    MODE_BIKE: {
        "bg": "#000000",
        "number": "#8fd6c8",
        "unit": "#ff8ec9",
        "event": "#eef6ff",
        "muted": "#7a8796",
        "delay": "#ff9f4a",
    },
    MODE_TRANSIT: {
        "bg": "#000000",
        "number": "#f0c36a",
        "unit": "#d7e3ff",
        "event": "#fff4ea",
        "muted": "#7a8796",
        "delay": "#ff9f4a",
    },
}

# -------------------------
# Config helpers
# -------------------------

def clip_text(value, max_len):
    if value == None:
        return ""
    if len(value) <= max_len:
        return value
    return value[0:max_len]

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

def mode_id(config):
    value = config.get("mode", MODE_DRIVE)
    if value in VALID_MODES:
        return value
    return MODE_DRIVE

def theme_id(config, mode):
    value = config.get("theme", THEME_AUTO)
    if value in THEMES:
        return value
    return mode

def label_text(config, key, fallback):
    value = config.str(key, fallback)
    if value == None:
        value = fallback
    value = clip_text(value.strip().upper(), LABEL_MAX)
    if value == "":
        return fallback
    return value

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

def parse_coord(value):
    if value == None:
        return None
    if type(value) == "int" or type(value) == "float":
        return value * 1.0
    if type(value) != "string":
        return None
    raw = value.strip()
    if raw == "":
        return None
    sign = 1.0
    if raw[0] == "-":
        sign = -1.0
        raw = raw[1:]
    elif raw[0] == "+":
        raw = raw[1:]
    if raw == "" or raw == ".":
        return None
    whole = "0"
    frac = ""
    seen_dot = False
    for i in range(len(raw)):
        c = raw[i]
        if c == ".":
            if seen_dot:
                return None
            seen_dot = True
            continue
        if c < "0" or c > "9":
            return None
        if seen_dot:
            frac += c
        else:
            whole += c
    number = int(whole) * 1.0
    if frac != "":
        denom = 1.0
        add = 0.0
        for i in range(len(frac)):
            denom = denom * 10.0
            add = add * 10.0 + int(frac[i])
        number += add / denom
    return sign * number

def location_coords(raw):
    if type(raw) == "dict":
        lat = parse_coord(raw.get("lat"))
        lng = parse_coord(raw.get("lng"))
        if lat == None or lng == None:
            return None
        if lat < -90 or lat > 90 or lng < -180 or lng > 180:
            return None
        return (lat, lng)
    if type(raw) != "string" or raw.strip() == "":
        return None
    lat = parse_coord(json_string_field(raw, "lat"))
    lng = parse_coord(json_string_field(raw, "lng"))
    if lat == None or lng == None:
        return None
    if lat < -90 or lat > 90 or lng < -180 or lng > 180:
        return None
    return (lat, lng)

def valid_api_key(key):
    if key == None or type(key) != "string":
        return False
    key = key.strip()
    if len(key) < 20 or len(key) > 200:
        return False
    for i in range(len(key)):
        c = key[i]
        letter = (c >= "A" and c <= "Z") or (c >= "a" and c <= "z")
        digit = c >= "0" and c <= "9"
        extra = c == "_" or c == "-"
        if not (letter or digit or extra):
            return False
    return True

def digits_only(value):
    if value == None or value == "":
        return False
    for i in range(len(value)):
        if value[i] < "0" or value[i] > "9":
            return False
    return True

def parse_seconds_value(raw):
    if raw == None:
        return None
    if type(raw) == "int":
        if raw < 0:
            return None
        return raw
    if type(raw) != "string":
        return None
    value = raw.strip()
    if value.endswith("s") or value.endswith("S"):
        value = value[0:len(value) - 1]
    if not digits_only(value):
        return None
    seconds = int(value)
    if seconds < 0 or seconds > 1000000:
        return None
    return seconds

def demo_trip(config):
    live = parse_seconds_value(config.get("demo_seconds"))
    if live == None:
        return None
    typical = parse_seconds_value(config.get("demo_static"))
    if typical == None:
        typical = live
    return (live, typical)

# -------------------------
# Routes
# -------------------------

def fetch_route(origin, dest, mode, api_key):
    payload = {
        "origin": {
            "location": {
                "latLng": {
                    "latitude": origin[0],
                    "longitude": origin[1],
                },
            },
        },
        "destination": {
            "location": {
                "latLng": {
                    "latitude": dest[0],
                    "longitude": dest[1],
                },
            },
        },
        "travelMode": GOOGLE_MODES[mode],
    }
    if mode == MODE_DRIVE:
        payload["routingPreference"] = "TRAFFIC_AWARE"

    res = http.post(
        url = ROUTES_URL,
        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": "routes.duration,routes.staticDuration",
        },
        body = json.encode(payload),
        ttl_seconds = CACHE_SECONDS,
    )
    if res.status_code != 200:
        return None
    data = res.json()
    if type(data) != "dict":
        return None
    routes = data.get("routes")
    if type(routes) != "list" or len(routes) == 0:
        return None
    route = routes[0]
    if type(route) != "dict":
        return None
    live = parse_seconds_value(route.get("duration"))
    typical = parse_seconds_value(route.get("staticDuration"))
    if live == None:
        return None
    if typical == None:
        typical = live
    return (live, typical)

def commute_view(trip):
    if trip == None:
        return {
            "status": "empty",
            "primary": "--",
            "unit": "MIN",
            "secondary": "",
        }

    live, typical = trip
    delay_min = 0
    if live > typical + 90:
        delay_min = int((live - typical + 30) / 60)

    hours = live // 3600
    minutes = (live % 3600) // 60
    if live < 60:
        minutes = 1 if live > 0 else 0

    extra = ""
    if delay_min > 0:
        extra = "+%d" % delay_min

    if hours >= 1:
        secondary = "%d MIN" % minutes if minutes > 0 else extra
        if minutes > 0 and extra:
            secondary = "%d MIN %s" % (minutes, extra)
        return {
            "status": "ok",
            "primary": str(hours),
            "unit": "HR" if hours == 1 else "HRS",
            "secondary": secondary,
        }
    return {
        "status": "ok",
        "primary": str(minutes),
        "unit": "MIN" if minutes == 1 else "MINS",
        "secondary": extra,
    }

# -------------------------
# Pixel scenes
# -------------------------

def px(x, y, w, h, color, scale):
    return render.Padding(
        pad = (x * scale, y * scale, 0, 0),
        child = render.Box(width = w * scale, height = h * scale, color = color),
    )

def paint(items, scale):
    return [px(item[0], item[1], item[2], item[3], item[4], scale) for item in items]

def scene_box(children, scale):
    return render.Stack(
        children = [render.Box(width = 24 * scale, height = 32 * scale, color = "#000000")] + children,
    )

def scene_drive(scale, frame):
    light = "#ffd166" if frame == 0 else "#7ec8ff"
    car_x = 3 + frame
    items = [
        (0, 22, 24, 3, "#2c3848"),
        (0, 25, 24, 2, "#1b2230"),
        (2, 18, 4, 3, "#5a6d82"),
        (8, 14, 5, 7, "#3e5168"),
        (16, 16, 6, 5, "#6a7d92"),
        (car_x, 20, 12, 4, "#e8eef6"),
        (car_x + 2, 18, 6, 2, "#7ec8ff"),
        (car_x + 11, 21, 2, 2, light),
        (car_x + 1, 23, 2, 2, "#2c3848"),
        (car_x + 8, 23, 2, 2, "#2c3848"),
        (20, 8, 1, 1, "#f4f1ff"),
        (14, 5 + frame, 1, 1, "#9bb0ff"),
    ]
    return scene_box(paint(items, scale), scale)

def scene_walk(scale, frame):
    person_x = 10 + frame
    items = [
        (0, 26, 24, 6, "#3d2a1c"),
        (0, 25, 24, 1, "#6a4220"),
        (2, 18, 4, 7, "#2f6b4f"),
        (17, 16, 5, 9, "#245742"),
        (person_x, 12, 2, 2, "#f4d6a5"),
        (person_x, 14, 2, 5, "#7ec8ff"),
        (person_x - 1, 19, 2, 3, "#3e5168"),
        (person_x + 1, 19 + frame, 2, 3, "#3e5168"),
        (person_x + 2, 15, 2, 1, "#c5d5e4"),
        (6, 8, 1, 1, "#fff6d8"),
    ]
    return scene_box(paint(items, scale), scale)

def scene_bike(scale, frame):
    bike_x = 4 + frame
    items = [
        (0, 27, 24, 5, "#2f6b4f"),
        (0, 24, 24, 3, "#3d2a1c"),
        (bike_x, 20, 4, 4, "#7ec8ff"),
        (bike_x + 8, 20, 4, 4, "#7ec8ff"),
        (bike_x + 2, 18, 8, 2, "#e8eef6"),
        (bike_x + 5, 14, 2, 4, "#ff8ec9"),
        (bike_x + 5, 12, 2, 2, "#f4d6a5"),
        (bike_x + 7, 16, 4, 1, "#c5d5e4"),
        (18, 6, 4, 4, "#ffd23f"),
        (2, 10, 3, 8, "#2c7a57"),
        (1, 8, 6, 4, "#36b068"),
    ]
    return scene_box(paint(items, scale), scale)

def scene_transit(scale, frame):
    train_x = 1 + frame
    door = "#f0c36a" if frame == 0 else "#d7e3ff"
    items = [
        (0, 26, 24, 6, "#2a241c"),
        (0, 22, 24, 2, "#6d7090"),
        (train_x, 12, 20, 10, "#4a5a8c"),
        (train_x, 10, 18, 2, "#3d4a7a"),
        (train_x + 2, 14, 3, 3, "#d7e3ff"),
        (train_x + 7, 14, 3, 3, door),
        (train_x + 12, 14, 3, 3, "#d7e3ff"),
        (train_x + 17, 16, 2, 4, "#f0c36a"),
        (2, 4, 1, 1, "#f4f1ff"),
        (19, 6, 1, 1, "#9bb0ff"),
        (11, 3 + frame, 1, 1, "#f4f1ff"),
    ]
    return scene_box(paint(items, scale), scale)

def render_scene(theme, scale, frame):
    if theme == MODE_WALK:
        return scene_walk(scale, frame)
    if theme == MODE_BIKE:
        return scene_bike(scale, frame)
    if theme == MODE_TRANSIT:
        return scene_transit(scale, frame)
    return scene_drive(scale, frame)

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

def build_text_column(view, route_name, colors, scale, width):
    number_color = colors["number"]
    unit_color = colors["unit"]
    if view["status"] != "ok":
        number_color = colors["muted"]
        unit_color = colors["muted"]
    if view["secondary"].startswith("+"):
        unit_color = colors["delay"]

    inner = width - 2 * scale
    if inner < 16:
        inner = width

    children = [
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
    ]
    if view["secondary"]:
        children.append(centered_text(view["secondary"], inner, unit_font(scale), colors["delay"] if view["secondary"].startswith("+") else colors["muted"]))
    children.append(named_marquee(route_name, inner, event_font(scale), colors["event"]))
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

def build_layout(view, route_name, theme, colors, scale):
    scene_w = 24 * scale
    text_w = canvas.width() - scene_w
    return render.Stack(
        children = [
            render.Box(width = canvas.width(), height = canvas.height(), color = "#000000"),
            render.Row(
                expanded = True,
                main_align = "start",
                cross_align = "center",
                children = [
                    build_text_column(view, route_name, colors, scale, text_w),
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
    mode = mode_id(config)
    theme = theme_id(config, mode)
    from_label = label_text(config, "from_label", DEFAULT_FROM)
    to_label = label_text(config, "to_label", DEFAULT_TO)
    route_name = "%s > %s" % (from_label, to_label)

    palette = THEMES[theme]
    colors = {
        "bg": "#000000",
        "number": palette["number"],
        "unit": palette["unit"],
        "event": palette["event"],
        "muted": palette["muted"],
        "delay": palette["delay"],
    }
    if config.bool("custom_colors", False):
        number_override = custom_hex(config, "number_color")
        event_override = custom_hex(config, "event_color")
        if number_override:
            colors["number"] = number_override
        if event_override:
            colors["event"] = event_override

    trip = demo_trip(config)
    if trip == None:
        origin = location_coords(config.get("origin"))
        dest = location_coords(config.get("destination"))
        api_key = config.get("api_key")
        if origin != None and dest != None and valid_api_key(api_key):
            trip = fetch_route(origin, dest, mode, api_key.strip())

    view = commute_view(trip)
    delay = 250 if scale == 2 else 450
    return render.Root(
        delay = delay,
        max_age = 600,
        show_full_animation = len(route_name) > 12,
        child = build_layout(view, route_name, theme, colors, scale),
    )

def color_fields(enabled):
    if enabled == True or enabled == "true" or enabled == "True":
        return [
            schema.Color(
                id = "number_color",
                name = "Number color",
                desc = "Color of the travel time.",
                icon = "brush",
                default = "#FFFFFF",
                palette = ["#FFFFFF", "#7EC8FF", "#F0C36A", "#8FD6C8", "#FFD166"],
            ),
            schema.Color(
                id = "event_color",
                name = "Label color",
                desc = "Color of the from and to names.",
                icon = "brush",
                default = "#E8EEF6",
                palette = ["#E8EEF6", "#FFF4EA", "#EEF6FF", "#FFF6D8"],
            ),
        ]
    return []

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "origin",
                name = "From",
                desc = "Where the trip starts.",
                icon = "locationDot",
            ),
            schema.Location(
                id = "destination",
                name = "To",
                desc = "Where you are going.",
                icon = "flag",
            ),
            schema.Text(
                id = "from_label",
                name = "From name",
                desc = "Short name for the starting place.",
                icon = "font",
                default = DEFAULT_FROM,
            ),
            schema.Text(
                id = "to_label",
                name = "To name",
                desc = "Short name for the destination.",
                icon = "font",
                default = DEFAULT_TO,
            ),
            schema.Dropdown(
                id = "mode",
                name = "Travel mode",
                desc = "How you are getting there.",
                icon = "car",
                default = MODE_DRIVE,
                options = [
                    schema.Option(display = "Drive", value = MODE_DRIVE),
                    schema.Option(display = "Walk", value = MODE_WALK),
                    schema.Option(display = "Bike", value = MODE_BIKE),
                    schema.Option(display = "Transit", value = MODE_TRANSIT),
                ],
            ),
            schema.Dropdown(
                id = "theme",
                name = "Visual theme",
                desc = "Pixel-art scene. Automatic matches the travel mode.",
                icon = "palette",
                default = THEME_AUTO,
                options = [
                    schema.Option(display = "Automatic", value = THEME_AUTO),
                    schema.Option(display = "Drive", value = MODE_DRIVE),
                    schema.Option(display = "Walk", value = MODE_WALK),
                    schema.Option(display = "Bike", value = MODE_BIKE),
                    schema.Option(display = "Transit", value = MODE_TRANSIT),
                ],
            ),
            schema.Text(
                id = "api_key",
                name = "Google Routes API key",
                desc = "Create a Google Cloud API key, enable Routes API, then paste it here. See the project README.",
                icon = "key",
            ),
            schema.Toggle(
                id = "custom_colors",
                name = "Custom colors",
                desc = "Override the theme colors for the time and labels.",
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
