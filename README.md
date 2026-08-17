# Cafeina

Cafeina is a native macOS menu bar app that keeps your Mac awake while enabled.

**Version 1.1** · **Requires macOS 13.0 or later**

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Features

- Toggle keep-awake from the menu bar cup icon
- Timed modes: 30 minutes, 1 hour, 2 hours, or indefinitely
- Optional Open at Login
- About, Privacy Policy, and Support links in the menu

## Download

Download the latest DMG from this repository:

[Download Cafeina.dmg](https://github.com/juandiab/Cafeina/raw/main/dist/Cafeina.dmg)

## Support

- Email: [support@nexxus-tech.com](mailto:support@nexxus-tech.com)
- Website: [www.nexxus-tech.com](https://www.nexxus-tech.com)
- Privacy: [www.nexxus-tech.com/cafeina/privacy](https://www.nexxus-tech.com/cafeina/privacy)

## Build

Open `Cafeina.xcodeproj` in Xcode, or build from the command line:

```bash
xcodebuild -project Cafeina.xcodeproj -scheme Cafeina -configuration Release build
```

## Create the DMG

The packaging script builds a Release app, ad-hoc signs it for local testing, stages `Cafeina.app`, and creates `dist/Cafeina.dmg`.

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

The DMG is intended for local distribution/testing and does not include App Store packaging or notarization support yet.

Cafeina is an independent app and is not affiliated with Caffeine or any similarly named products.
