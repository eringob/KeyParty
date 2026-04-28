# Changelog

All notable changes to this project are documented in this file.

### [1.5.1] - 2026-04-28

### Added
- Added support for closing the UI frame by pressing the Escape key.

### [1.5.0] - 2026-04-16

### Added
- Added `KeyPartySeasonData.lua` as the dedicated source for season-specific dungeon definitions, including map IDs, teleport spell IDs, and display names.
- Added UI scaling controls in the header with `+` and `-` buttons, with persistent saved scale between sessions.
- Added a bottom-right drag handle to scale the full UI frame by dragging.
- Added `/kp demo` to populate the addon with the local player plus four fictional party members for UI preview and testing.
- Added realistic demo party data, including dungeon scores, total Mythic+ rating, available keystones, and highest completed key runs.
- Added `/kp ver` and `/kp version` to report which party members are using Key Party and which addon version they have installed.

### Changed
- Season dungeon and teleport mappings are now driven from `KeyPartySeasonData.lua` instead of hardcoded season-specific entries in `KeyParty.lua`.
- Updated the bundled season data to Midnight Season 1 dungeon definitions.
- The YOUR SCORES row now derives displayed season dungeons from `KeyPartySeasonData.lua`, so the UI matches the configured season dataset explicitly.
- The title header now supports the updated banner artwork and keeps the control buttons in a dedicated strip above the banner image.
- Banner sizing now preserves the artwork aspect ratio based on the active banner texture dimensions.
- The title banner now sits inside the inner border of the frame instead of touching the outer border edge.
- The bottom status line now shows the addon version before the last refresh timestamp.
- The YOUR SCORES tiles now render the score at the bottom of the icon instead of centered.
- Key level text in YOUR SCORES tiles now uses the same color as the corresponding dungeon score.
- Increased spacing between the bottom `Auto open after dungeon finish` and `Party chat announcement Best Progression Key after dungeon finish` options while keeping all content inside the frame.

### Fixed
- Default teleport mappings from the active season file now always override stale SavedVariables mappings from older seasons.
- Corrected demo data population so seasonal dungeon map IDs are read from structured season entries, allowing highest completed key runs and per-dungeon scores to appear correctly in the UI.
- Fixed a UI load failure caused by misplaced scale button code inside the weekly affix layout block.

### [1.4.1] - 2026-04-12

### Fixed
- Teleport spell detection now handles updated spell IDs more reliably and can reconcile stale portal mappings against the player's spellbook.
- Corrected several default dungeon portal spell mappings, including `Maisara Caverns` and other season dungeons.
- Dungeon tiles now show the correct teleport availability state, including green borders and `Click to teleport` tooltips when a teleport is available.
- Teleport tiles now cast reliably when clicked.
- Teleport cooldowns now refresh correctly after use and are shown consistently across all tiles that have a teleport available.
- The UI now closes automatically when entering combat and reopens after combat if it had been open before combat started.

### Added
- Added `/kp debugportal` to print mapped teleport spells, resolved spell names, and known-state diagnostics per dungeon.

### [1.4.0] - 2026-04-06

### Fixed
- The main UI title banner now preserves the source artwork aspect ratio, preventing the header image from appearing squashed or stretched.
- The frame height is now derived from the banner height so the header scales cleanly without clipping the rest of the layout.

### Changed
- Updated the bundled `media/title-banner` artwork to match the new header proportions.

### [1.3.10] - 2026-04-05

### Added
- GROUP RATINGS now shows a third column with the best completed dungeon per player: the dungeon icon, the abbreviation used in YOUR SCORES, and the key level. The level is shown in white when the run was timed, and dimmed/transparent when depleted.

### [1.3.9] - 2026-04-05

### Fixed
- Close and Refresh buttons are now parented to the title bar frame instead of the main frame, so they always render above the banner artwork.

### Changed
- YOUR SCORES icons are now sorted from lowest score to highest, re-evaluated on every data refresh. Ties are broken alphabetically.

### [1.3.8] - 2026-04-05

### Changed
- YOUR SCORES icons are now sorted from lowest score to highest.

### [1.3.7] - 2026-04-02

### Changed
- End-of-dungeon refresh no longer sends `!keys` when the `Party chat announcement` option is disabled.
- Weekly affix icons now use the correct Mythic+ activation levels and show the fifth affix at `+12`.

## [1.3.6.1] - 2026-04-02

### Fixed
- Restored the version in KeyParty.toc

## [1.3.6] - 2026-04-01

### Fixed
- Made the header `Close` and `Refresh` buttons render reliably by anchoring them to the title bar and giving them explicit button chrome and frame layering, so they no longer disappear behind the banner artwork.

## [1.3.5] - 2-26-03-31

### Changed
- Clarified release notes around manual inspect compatibility: background addon inspect requests are intentionally disabled by default to avoid interfering with Blizzard inspect gear and item-level views.

## [1.3.2] - 2026-03-31

### Fixed
- Hardened inspect queue handling so Key Party no longer interrupts manual player inspection in the default Inspect window.
- `INSPECT_READY` is now ignored unless it matches the addon's active inspect request GUID.
- Added timeout cleanup for stale inspect requests to prevent inspect flow from getting stuck.
- `ClearInspectPlayer()` is no longer called while the default Inspect frame is visible.
- Disabled background `NotifyInspect` requests by default as a fail-safe to prevent all remaining conflicts with manual inspect gear/ilvl views.

## [1.3.0] - 2026-03-30

### Changed
- Repository ignore rules now also ignore `.gitignore` itself.
- Internal identifiers were renamed from `KeyLottery` to `KeyParty`, including SavedVariables and addon message prefix usage.
- Opening the Key Party frame for the first time after login now immediately triggers a data refresh.
- The refresh button now uses an icon instead of the `Refresh` text label.
- The refresh header button now uses a WoW atlas icon instead of a Unicode glyph fallback.
- The close button now matches the refresh button with the same compact icon-button styling.
- The refresh and close header icons are now aligned on the same baseline with consistent spacing.
- When no keystone is available, keystone sections now show a Mythic+ keystone icon instead of a question mark.
- Added a checkbox option for a party chat Best Progression Key announcement after dungeon completion.
- Group rating names now include the player's realm when that player is on a different realm.
- The main frame height was increased so the end-of-dungeon option checkboxes fit fully inside the UI.
- The bottom option checkboxes and labels were reduced in size, and the auto-open label text was updated.
- The addon now warns the local player in chat when a newer Key Party version is detected in the current group.
- End-of-dungeon announcement text now omits embedded addon prefixes for local output, and uses `Key Party:` when sent to group chat.
- Bottom status and checkbox anchors were adjusted so `Last refresh`, `Auto open`, and `Party chat` stay fully inside the frame.

## [1.2.0] - 2026-03-30

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
- Dungeon run level extraction from Blizzard Mythic+ rating summary (`bestRunLevel`) for per-dungeon key level display.
- `YOUR SCORES` icons now show the highest completed key level per dungeon.
- `AVAILABLE KEYSTONES` redesigned as large horizontal party keystone icons.
- Weekly affix column with a `2x2` grid next to party keystones.
- Weekly affix tooltips with affix name, activation level, and description.
- End-of-dungeon chat announcement for the best progression key when at least one party member is not using the addon.
- `/kp testbestkeyannouncement` to test that chat announcement locally while solo.

### Changed
- Header artwork changed from separate icon/wordmark textures to one full-width banner texture with preserved aspect ratio.
- Frame height increased to make bottom options visible (`FRAME_H` now 740).
- Icon border rendering changed to true edge borders around icon textures.
- Score text rendering now uses colored score values with black outline for readability.
- Status text simplified to remove explicit `/kp refresh` instruction.
- Slash command usage prompt shown to users is now limited to `/kp [refresh|report]`.
- README usage section now distinguishes user commands and internal developer commands.
- BEST PROGRESSION KEY now shows the key level inside the dungeon icon instead of beside the dungeon name.
- AVAILABLE KEYSTONES now show dungeon abbreviations in icons and owner names below the icons.
- Owner names under keystone icons are width-limited and truncated with `...` when necessary.
- All key level overlays now use white text.
- Weekly affix column label text removed in favor of icon-only presentation.
- Icon borders were reduced to a thinner edge style.
- Status text was moved lower so it no longer overlaps the BEST PROGRESSION KEY section.

### Removed
- Manual key entry UI (`Set Key` button and popup form).
- `/kp setkey` slash command and related manual key handling callback wiring.
- Tooltip tip line that referenced `/kp setportal`.
- OPTIONS section header label in the UI (separator + label text removed).
- Legacy title textures `media/title-icon` and `media/title-wordmark`.
