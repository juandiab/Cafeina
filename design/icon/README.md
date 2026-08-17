# Cafeina app icon

Source of truth for the macOS app icon. Three hand-authored SVG candidates, a
renderer that goes through AppKit's own SVG engine (so what you see is what
Xcode/macOS draw), and a contact sheet for judging legibility.

All candidates use the standard macOS Big Sur icon geometry: a 1024x1024 canvas
with an 824x824 rounded tile at (100,100), corner radius 184.5 (22.37% of the tile
side). The margin outside the tile is transparent; macOS adds the drop shadow.
No text, no drop shadow baked outside the tile.

## Candidates

| | Concept | Palette |
|---|---|---|
| **A — Crema Power** (installed) | A cup seen from directly above; the latte art in the crema is the ⏻ power glyph. One object, one accent. | tile espresso `#4A2B1B → #341C11 → #22120A`, porcelain `#FFF9EC → #E3CDA6`, coffee `#7E4526 → #33190D`, crema-gold accent `#FFF0CC → #FBD68C → #F2A93B` |
| B — Bean Eye | A coffee bean whose seam is the slit pupil of a wide-open amber eye. Bean = coffee, eye = awake. Light crema tile so it stands out among dark Dock icons. | tile crema `#FBF2E2 → #E4CBA0`, bean `#4E2D1B → #1C0E07`, iris `#FFDF8F → #F7B248 → #C96A16` |
| C — Sunrise Cup | A wide porcelain cup at dawn; instead of steam, an amber sun rises out of it. | tile dawn `#2B160D → #4E2716 → #8E4A2A`, porcelain `#FFF9EC → #DFC8A0`, sun `#FFE9B0 → #FDC565 → #F0982F`, coffee `#3A1C0E → #6E3A1D` |

**Why A:** it says "coffee" and "on" in a single silhouette, is unmistakably not
the classic side-view Caffeine cup (guideline 4.1), and holds up at 32 px (ring +
stem still legible) and 16 px (bright glyph inside a cream ring). B is the most
distinctive but an eye can read as a surveillance/privacy tool; C is charming but
illustrative, and its rays vanish below 64 px.

## Files

- `candidate-A.svg`, `candidate-B.svg`, `candidate-C.svg` — sources (1024x1024).
- `render.swift` — rasterizes an SVG to `icon_<size>.png` (16…1024) via `NSImage`.
- `contact-sheet.swift` — builds `contact-sheet.png` (512/128/64/32/16 on light and
  dark backgrounds, plus 4x nearest-neighbour blow-ups of 32 and 16).
- `renders/<A|B|C>/icon_512.png`, `icon_32.png` — quick previews of each candidate.
- Installed icon set: `Cafeina/Assets.xcassets/AppIcon.appiconset/`.

## Re-render

```sh
# previews / any size list
swift design/icon/render.swift design/icon/candidate-A.svg /tmp/cafeina-icon 16 32 64 128 256 512 1024

# contact sheet (ZOOM=8 for closer inspection of the small sizes)
swift design/icon/contact-sheet.swift design/icon/contact-sheet.png \
  design/icon/candidate-A.svg design/icon/candidate-B.svg design/icon/candidate-C.svg
```

To install a candidate, render all sizes and copy into the appiconset with the
filenames from its `Contents.json`:

```
icon_16x16.png=16   icon_16x16@2x.png=32   icon_32x32.png=32   icon_32x32@2x.png=64
icon_128x128.png=128 icon_128x128@2x.png=256 icon_256x256.png=256 icon_256x256@2x.png=512
icon_512x512.png=512 icon_512x512@2x.png=1024
```

The SVGs only use features CoreSVG (macOS 11+) supports: paths, linear/radial
gradients, gradient strokes, `clipPath`, and `feGaussianBlur` for the soft
shadows. Avoid text, external fonts, masks, and other filter primitives.
