# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-03-30

### Added
- Addon presence probing in party groups using `PING_REQ` and `PING_ACK` addon messages.
- Automatic group roster probe trigger on `GROUP_ROSTER_UPDATE`.
- `debugaddon` slash command for addon presence diagnostics.
- Group communication safety guard to limit addon/group communication logic to groups of 5 or fewer players.
- YOUR SCORES icon row in the UI with per-dungeon score display.
- Cooldown overlays on dungeon teleport icons (both YOUR SCORES and BEST PROGRESSION KEY).
- Debug cooldown controls via `/kp debugcooldown`, `/kp debugcooldown <seconds>`, and `/kp debugcooldown off`.
- Blizzard API based score-color probing for dungeon score rarity, with debug output via `/kp debugcolors`.
- End-of-dungeon auto-refresh scheduling and optional auto-open behavior.
- UI checkbox setting: "Auto open at the end of a dungeon".
- `/kp testdungeonend` to simulate end-of-dungeon refresh behavior.
- Header banner support via `media/title-banner`.
- New media assets: `media/title-banner` and `media/minimap-icon`.

### Changed
- Header artwork changed from separate icon/wordmark textures to one full-width banner texture with preserved aspect ratio.
- Frame height increased to make bottom options visible (`FRAME_H` now 740).
- Icon border rendering changed to true edge borders around icon textures.
- Score text rendering now uses colored score values with black outline for readability.
- Status text simplified to remove explicit `/kp refresh` instruction.
- Slash command usage prompt shown to users is now limited to `/kp [refresh|report]`.
- README usage section now distinguishes user commands and internal developer commands.

### Removed
- Manual key entry UI (`Set Key` button and popup form).
- `/kp setkey` slash command and related manual key handling callback wiring.
- Tooltip tip line that referenced `/kp setportal`.
- OPTIONS section header label in the UI (separator + label text removed).
- Legacy title textures `media/title-icon` and `media/title-wordmark`.
