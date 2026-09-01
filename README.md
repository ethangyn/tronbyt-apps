# Tronbyt Apps

Free apps for [Tronbyt](https://github.com/tronbyt/server) and compatible Tidbyt displays.

## Visual Countdown

Count down to an event with a large remaining-time value, the event name, and an original pixel-art scene.

| Birthday | Travel | Holiday |
| --- | --- | --- |
| ![Birthday](docs/previews/birthday.gif) | ![Travel](docs/previews/travel.gif) | ![Holiday](docs/previews/holiday.gif) |

| Launch | Wedding | Summer |
| --- | --- | --- |
| ![Launch](docs/previews/launch.gif) | ![Wedding](docs/previews/wedding.gif) | ![Summer](docs/previews/summer.gif) |

| Work | Graduation | Baby | Home |
| --- | --- | --- | --- |
| ![Work](docs/previews/work.gif) | ![Graduation](docs/previews/graduation.gif) | ![Baby](docs/previews/baby.gif) | ![Home](docs/previews/home.gif) |

Themes: celebration (the default), birthday, travel, summer, holiday, launch, wedding, work, graduation, baby, and home.

Choose the event name and date, optionally count down to an exact time, and personalize the display with a theme and custom colors. Your location keeps the countdown aligned with your local date and time.

Display the remaining time automatically or in days, weeks, months, years, months + days, or years + months + days. Calendar-based modes account for the actual length of each month and year.

Supports **64×32** and **128×64** displays.

## Use it

Anyone can use this. It is licensed under [Apache License 2.0](LICENSE).

### On Tronbyt

1. Open Tronbyt Manager as an administrator.
2. Set **Custom App Repo** to `https://github.com/ethangyn/tronbyt-apps.git`
3. Refresh the app list. Leave the main system app repo as it is.
4. On your device, add **Visual Countdown**.
5. Enter an event name and date, pick a theme, and save.

If the app does not appear, refresh the custom app repo again.

### On your computer

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
