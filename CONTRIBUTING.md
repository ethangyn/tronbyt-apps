# Contributing

Bug fixes, documentation improvements, and new original apps are welcome.

## Apps

Follow current [Tronbyt](https://github.com/tronbyt/apps) and [Pixlet](https://github.com/tronbyt/pixlet) conventions.

- Put each app in `apps/<packagename>/` with a `manifest.yaml` and a `.star` file.
- Do not copy source, artwork, or branding from other apps.
- Provide defaults for every schema field.
- Support 64×32 first. Add 128×64 only if the layout stays readable.
- Add a preview with `pixlet render -z 9`. If the app sets `supports2x`, also render with `-2`.
- Run `pixlet check apps/<packagename>` before opening a pull request.
- Mention the app in the root README.
