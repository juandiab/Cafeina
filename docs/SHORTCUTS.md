# Shortcuts & Siri

Cafeina exposes its keep-awake controls as App Intents (macOS 13+), so you can drive it from the Shortcuts app, Siri, Focus-mode automations, and third-party launchers that call Shortcuts (Raycast, Stream Deck, Alfred, BetterTouchTool, …).

## Actions

| Action | What it does | Parameters | Result |
| --- | --- | --- | --- |
| **Keep Mac Awake** | Turns Cafeina on | Duration: 30 Minutes, 1 Hour, 2 Hours, Indefinitely (default) | Dialog with the new state |
| **Turn Off Cafeina** | Turns Cafeina off | — | Dialog |
| **Toggle Cafeina** | Off if on; on indefinitely if off | — | Dialog with the new state |
| **Get Cafeina Status** | Reports whether Cafeina is on | — | Boolean (`true` = on) + dialog, including "until h:mm" for timed modes |

Cafeina must be installed (and, ideally, running) — the actions run inside the app, and the menu bar icon updates immediately.

## Siri phrases

- "Keep my Mac awake with Cafeina" / "Turn on Cafeina"
- "Turn off Cafeina"
- "Toggle Cafeina"
- "Is Cafeina on"

The **Keep Mac Awake** action asks for a duration when run from Siri; in a shortcut you can preset it.

## Example automations

### 1. Focus "Presentation" turns on → keep awake indefinitely

1. Open **Shortcuts › Automation › New Automation › Focus**.
2. Choose your presentation Focus, **When Turning On**, **Run Immediately**.
3. Add the action **Keep Mac Awake** (Cafeina) and set Duration to **Indefinitely**.

### 2. Focus turns off → turn Cafeina off

1. **Shortcuts › Automation › New Automation › Focus**.
2. Same Focus, **When Turning Off**, **Run Immediately**.
3. Add **Turn Off Cafeina**.

### 3. "Keep awake for 1 hour" Siri phrase

1. In Shortcuts, create a new shortcut named **Keep awake for 1 hour**.
2. Add **Keep Mac Awake** and set Duration to **1 Hour**.
3. Say "Hey Siri, keep awake for 1 hour" — Siri runs shortcuts by name.

You can also run any saved shortcut from the terminal or a launcher:

```bash
shortcuts run "Keep awake for 1 hour"
```
