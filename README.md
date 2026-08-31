# Tronbyt Apps

Apps for [Tronbyt](https://github.com/tronbyt/server) and compatible Tidbyt displays, written in Starlark and rendered with [Pixlet](https://github.com/tronbyt/pixlet).

## Visual Countdown

Count down to an event with a large remaining-time value, the event name, and an original pixel-art scene.

| Birthday | Travel | Holiday |
| --- | --- | --- |
| ![Birthday](docs/previews/birthday.gif) | ![Travel](docs/previews/travel.gif) | ![Holiday](docs/previews/holiday.gif) |

| Launch | Wedding | Summer |
| --- | --- | --- |
| ![Launch](docs/previews/launch.gif) | ![Wedding](docs/previews/wedding.gif) | ![Summer](docs/previews/summer.gif) |

Themes: celebration, birthday, travel, summer, holiday, launch, and wedding.

Choose the event name and date, optionally count down to an exact time, and personalize the display with a theme and custom colors. Your location keeps the countdown aligned with your local date and time.

Display the remaining time automatically or in days, weeks, months, years, months + days, or years + months + days. Calendar-based modes account for the actual length of each month and year.

Supports **64×32** and **128×64** displays.

## Development

Install [Pixlet](https://github.com/tronbyt/pixlet/releases/latest) and put it on your `PATH`. This repository targets Pixlet v0.53.1.

```
pixlet serve apps/visualcountdown/visual_countdown.star
```

Open [http://localhost:8080](http://localhost:8080). Example:

```
http://localhost:8080/?event_name=JAPAN&event_time=2026-12-09&theme=travel&mode=days
```

```
pixlet render apps/visualcountdown/visual_countdown.star event_name="JAPAN" event_time="2026-12-09" theme=travel
pixlet check apps/visualcountdown
```

When using Pixlet directly, settings are passed as query parameters or render arguments. Date-only values such as `2026-12-09` use that calendar day in the configured timezone. Event names are limited to 32 characters.

Each app lives in `apps/<name>/` with a `manifest.yaml`, Starlark source, and preview images — the same layout as [tronbyt/apps](https://github.com/tronbyt/apps).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[Apache License 2.0](LICENSE)
