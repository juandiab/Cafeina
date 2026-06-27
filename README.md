# Cafeina

Cafeina is a native macOS menu bar app that keeps your Mac awake while enabled.

## Download

Download the latest DMG from this repository:

[Download Cafeina.dmg](https://github.com/juandiab/Cafeina/raw/master/dist/Cafeina.dmg)

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
